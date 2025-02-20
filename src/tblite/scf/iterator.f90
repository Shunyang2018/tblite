! This file is part of tblite.
! SPDX-Identifier: LGPL-3.0-or-later
!
! tblite is free software: you can redistribute it and/or modify it under
! the terms of the GNU Lesser General Public License as published by
! the Free Software Foundation, either version 3 of the License, or
! (at your option) any later version.
!
! tblite is distributed in the hope that it will be useful,
! but WITHOUT ANY WARRANTY; without even the implied warranty of
! MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
! GNU Lesser General Public License for more details.
!
! You should have received a copy of the GNU Lesser General Public License
! along with tblite.  If not, see <https://www.gnu.org/licenses/>.

module tblite_scf_iterator
   use mctc_env, only : wp, error_type
   use mctc_io, only : structure_type
   use tblite_basis_type, only : basis_type
   use tblite_container, only : container_cache, container_list
   use tblite_coulomb_cache, only : coulomb_cache
   use tblite_disp, only : dispersion_type, dispersion_cache
   use tblite_integral_type, only : integral_type
   use tblite_scf_broyden, only : broyden_mixer, new_broyden
   use tblite_wavefunction_type, only : wavefunction_type, get_density_matrix
   use tblite_wavefunction_fermi, only : get_fermi_filling
   use tblite_wavefunction_mulliken, only : get_mulliken_shell_charges, &
      & get_mulliken_atomic_multipoles
   use tblite_xtb_coulomb, only : tb_coulomb
   use tblite_scf_info, only : scf_info
   use tblite_scf_potential, only : potential_type, add_pot_to_h1
   use tblite_scf_solver, only : solver_type
   use tblite_output_property, only : property, write(formatted)
   implicit none
   private

   public :: next_scf, get_mixer_dimension

contains

!> Evaluate self-consistent iteration for the density-dependent Hamiltonian
subroutine next_scf(iscf, mol, bas, wfn, solver, mixer, info, coulomb, dispersion, &
      & interactions, ints, pot, cache, dcache, icache, &
      & energy, error)
   !> Current iteration count
   integer, intent(inout) :: iscf
   !> Molecular structure data
   type(structure_type), intent(in) :: mol
   !> Basis set information
   type(basis_type), intent(in) :: bas
   !> Tight-binding wavefunction data
   type(wavefunction_type), intent(inout) :: wfn
   !> Solver for the general eigenvalue problem
   class(solver_type), intent(inout) :: solver
   !> Convergence accelerator
   type(broyden_mixer), intent(inout) :: mixer
   !> Information on wavefunction data used to construct Hamiltonian
   type(scf_info), intent(in) :: info
   !> Container for coulombic interactions
   type(tb_coulomb), intent(in), optional :: coulomb
   !> Container for dispersion interactions
   class(dispersion_type), intent(in), optional :: dispersion
   !> Container for general interactions
   type(container_list), intent(in), optional :: interactions

   !> Integral container
   type(integral_type), intent(in) :: ints
   !> Density dependent potential shifts
   type(potential_type), intent(inout) :: pot
   !> Restart data for coulombic interactions
   type(coulomb_cache), intent(inout) :: cache
   !> Restart data for dispersion interactions
   type(dispersion_cache), intent(inout) :: dcache
   !> Restart data for interaction containers
   type(container_cache), intent(inout) :: icache

   !> Self-consistent energy
   real(wp), intent(inout) :: energy

   !> Error handling
   type(error_type), allocatable, intent(out) :: error

   real(wp) :: elast, ts, e_fermi, edisp, ees, eelec, eint

   if (iscf > 0) then
      call mixer%next
      call get_mixer(mixer, bas, wfn, info)
   end if

   iscf = iscf + 1
   call pot%reset
   if (present(coulomb)) then
      call coulomb%get_potential(mol, cache, wfn, pot)
   end if
   if (present(dispersion)) then
      call dispersion%get_potential(mol, dcache, wfn, pot)
   end if
   if (present(interactions)) then
      call interactions%get_potential(mol, icache, wfn, pot)
   end if
   call add_pot_to_h1(bas, ints, pot, wfn%coeff)

   call set_mixer(mixer, wfn, info)

   call solver%solve(wfn%coeff, ints%overlap, wfn%emo, error)
   if (allocated(error)) return

   call get_fermi_filling(wfn%nocc, wfn%nuhf, wfn%kt, wfn%emo, &
      & wfn%homoa, wfn%homob, wfn%focc, e_fermi, ts)
   call get_density_matrix(wfn%focc, wfn%coeff, wfn%density)

   call get_mulliken_shell_charges(bas, ints%overlap, wfn%density, wfn%n0sh, wfn%qsh)

   call get_mulliken_atomic_multipoles(bas, ints%dipole, wfn%density, wfn%dpat)
   call get_mulliken_atomic_multipoles(bas, ints%quadrupole, wfn%density, wfn%qpat)

   call diff_mixer(mixer, wfn, info)

   ees = 0.0_wp
   edisp = 0.0_wp
   eint = 0.0_wp
   eelec = 0.0_wp
   elast = energy
   call get_electronic_energy(ints%hamiltonian, wfn%density, eelec)
   if (present(coulomb)) then
      call coulomb%get_energy(mol, cache, wfn, ees)
   end if
   if (present(dispersion)) then
      call dispersion%get_energy(mol, dcache, wfn, edisp)
   end if
   if (present(interactions)) then
      call interactions%get_energy(mol, icache, wfn, eint)
   end if
   energy = ts + eelec + ees + edisp + eint

end subroutine next_scf


subroutine get_electronic_energy(h0, density, energy)
   real(wp), intent(in) :: h0(:, :)
   real(wp), intent(in) :: density(:, :)
   real(wp), intent(inout) :: energy

   integer :: iao, jao

   !$omp parallel do collapse(2) schedule(runtime) default(none) &
   !$omp reduction(+:energy) shared(h0, density) private(iao, jao)
   do iao = 1, size(h0, 2)
      do jao = 1, size(h0, 1)
         energy = energy + h0(jao, iao) * density(jao, iao)
      end do
   end do
end subroutine get_electronic_energy


subroutine get_qat_from_qsh(bas, qsh, qat)
   type(basis_type), intent(in) :: bas
   real(wp), intent(in) :: qsh(:)
   real(wp), intent(out) :: qat(:)

   integer :: ish

   qat(:) = 0.0_wp
   !$omp parallel do schedule(runtime) default(none) &
   !$omp reduction(+:qat) shared(bas, qsh) private(ish)
   do ish = 1, size(qsh)
      qat(bas%sh2at(ish)) = qat(bas%sh2at(ish)) + qsh(ish)
   end do
end subroutine get_qat_from_qsh


function get_mixer_dimension(mol, bas, info) result(ndim)
   use tblite_scf_info, only : atom_resolved, shell_resolved
   type(structure_type), intent(in) :: mol
   type(basis_type), intent(in) :: bas
   type(scf_info), intent(in) :: info
   integer :: ndim

   ndim = 0

   select case(info%charge)
   case(atom_resolved)
      ndim = ndim + mol%nat
   case(shell_resolved)
      ndim = ndim + bas%nsh
   end select

   select case(info%dipole)
   case(atom_resolved)
      ndim = ndim + 3*mol%nat
   end select

   select case(info%quadrupole)
   case(atom_resolved)
      ndim = ndim + 6*mol%nat
   end select
end function get_mixer_dimension

subroutine set_mixer(mixer, wfn, info)
   use tblite_scf_info, only : atom_resolved, shell_resolved
   type(broyden_mixer), intent(inout) :: mixer
   type(wavefunction_type), intent(in) :: wfn
   type(scf_info), intent(in) :: info

   select case(info%charge)
   case(atom_resolved)
      call mixer%set(wfn%qat)
   case(shell_resolved)
      call mixer%set(wfn%qsh)
   end select

   select case(info%dipole)
   case(atom_resolved)
      call mixer%set(wfn%dpat)
   end select

   select case(info%quadrupole)
   case(atom_resolved)
      call mixer%set(wfn%qpat)
   end select
end subroutine set_mixer

subroutine diff_mixer(mixer, wfn, info)
   use tblite_scf_info, only : atom_resolved, shell_resolved
   type(broyden_mixer), intent(inout) :: mixer
   type(wavefunction_type), intent(in) :: wfn
   type(scf_info), intent(in) :: info

   select case(info%charge)
   case(atom_resolved)
      call mixer%diff(wfn%qat)
   case(shell_resolved)
      call mixer%diff(wfn%qsh)
   end select

   select case(info%dipole)
   case(atom_resolved)
      call mixer%diff(wfn%dpat)
   end select

   select case(info%quadrupole)
   case(atom_resolved)
      call mixer%diff(wfn%qpat)
   end select
end subroutine diff_mixer

subroutine get_mixer(mixer, bas, wfn, info)
   use tblite_scf_info, only : atom_resolved, shell_resolved
   type(broyden_mixer), intent(inout) :: mixer
   type(basis_type), intent(in) :: bas
   type(wavefunction_type), intent(inout) :: wfn
   type(scf_info), intent(in) :: info

   select case(info%charge)
   case(atom_resolved)
      call mixer%get(wfn%qat)
   case(shell_resolved)
      call mixer%get(wfn%qsh)
      call get_qat_from_qsh(bas, wfn%qsh, wfn%qat)
   end select

   select case(info%dipole)
   case(atom_resolved)
      call mixer%get(wfn%dpat)
   end select

   select case(info%quadrupole)
   case(atom_resolved)
      call mixer%get(wfn%qpat)
   end select
end subroutine get_mixer

end module tblite_scf_iterator

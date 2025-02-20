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

!> Isotropic third-order onsite correction
module tblite_coulomb_thirdorder
   use mctc_env, only : wp
   use mctc_io, only : structure_type
   use tblite_coulomb_cache, only : coulomb_cache
   use tblite_coulomb_charge, only : effective_coulomb
   use tblite_coulomb_multipole, only : damped_multipole
   use tblite_coulomb_type, only : coulomb_type
   use tblite_scf_potential, only : potential_type
   use tblite_wavefunction_type, only : wavefunction_type
   implicit none
   private

   public :: onsite_thirdorder, new_onsite_thirdorder

   type, extends(coulomb_type) :: onsite_thirdorder
      logical :: shell_resolved
      integer, allocatable :: nsh_at(:)
      integer, allocatable :: ish_at(:)
      real(wp), allocatable :: hubbard_derivs(:, :)
   contains
      procedure :: update
      procedure :: variable_info
      procedure :: get_energy
      procedure :: get_potential
      procedure :: get_gradient
   end type onsite_thirdorder

contains


subroutine new_onsite_thirdorder(self, mol, hubbard_derivs, nshell)
   !> Instance of the electrostatic container
   type(onsite_thirdorder), intent(out) :: self
   !> Molecular structure data
   type(structure_type), intent(in) :: mol
   !> Hubbard derivatives
   real(wp), intent(in) :: hubbard_derivs(:, :)
   !> Number of shells for each species
   integer, intent(in), optional :: nshell(:)

   integer :: ind, iat

   self%hubbard_derivs = hubbard_derivs

   self%shell_resolved = present(nshell)
   if (present(nshell)) then
      self%nsh_at = nshell(mol%id)

      allocate(self%ish_at(mol%nat))
      ind = 0
      do iat = 1, mol%nat
         self%ish_at(iat) = ind
         ind = ind + self%nsh_at(iat)
      end do
   end if

end subroutine new_onsite_thirdorder


subroutine update(self, mol, cache)
   !> Instance of the electrostatic container
   class(onsite_thirdorder), intent(in) :: self
   !> Molecular structure data
   type(structure_type), intent(in) :: mol
   !> Reusable data container
   type(coulomb_cache), intent(inout) :: cache

end subroutine update


subroutine get_energy(self, mol, cache, wfn, energy)
   !> Instance of the electrostatic container
   class(onsite_thirdorder), intent(in) :: self
   !> Molecular structure data
   type(structure_type), intent(in) :: mol
   !> Reusable data container
   type(coulomb_cache), intent(inout) :: cache
   !> Wavefunction data
   type(wavefunction_type), intent(in) :: wfn
   !> Electrostatic energy
   real(wp), intent(inout) :: energy

   integer :: iat, izp, ii, ish

   if (self%shell_resolved) then
      do iat = 1, mol%nat
         izp = mol%id(iat)
         ii = self%ish_at(iat)
         do ish = 1, self%nsh_at(iat)
            energy = energy + wfn%qsh(ii+ish)**3 * self%hubbard_derivs(ish, izp) / 3.0_wp
         end do
      end do
   else
      do iat = 1, mol%nat
         izp = mol%id(iat)
         energy = energy + wfn%qat(iat)**3 * self%hubbard_derivs(1, izp) / 3.0_wp
      end do
   end if
end subroutine get_energy


subroutine get_potential(self, mol, cache, wfn, pot)
   !> Instance of the electrostatic container
   class(onsite_thirdorder), intent(in) :: self
   !> Molecular structure data
   type(structure_type), intent(in) :: mol
   !> Reusable data container
   type(coulomb_cache), intent(inout) :: cache
   !> Wavefunction data
   type(wavefunction_type), intent(in) :: wfn
   !> Density dependent potential
   type(potential_type), intent(inout) :: pot

   integer :: iat, izp, ii, ish

   if (self%shell_resolved) then
      do iat = 1, mol%nat
         izp = mol%id(iat)
         ii = self%ish_at(iat)
         do ish = 1, self%nsh_at(iat)
            pot%vsh(ii+ish) = pot%vsh(ii+ish) &
               & + wfn%qsh(ii+ish)**2 * self%hubbard_derivs(ish, izp)
         end do
      end do
   else
      do iat = 1, mol%nat
         izp = mol%id(iat)
         pot%vat(iat) = pot%vat(iat) + wfn%qat(iat)**2 * self%hubbard_derivs(1, izp)
      end do
   end if
end subroutine get_potential


subroutine get_gradient(self, mol, cache, wfn, gradient, sigma)
   !> Instance of the electrostatic container
   class(onsite_thirdorder), intent(in) :: self
   !> Molecular structure data
   type(structure_type), intent(in) :: mol
   !> Reusable data container
   type(coulomb_cache), intent(inout) :: cache
   !> Wavefunction data
   type(wavefunction_type), intent(in) :: wfn
   !> Molecular gradient of the repulsion energy
   real(wp), contiguous, intent(inout) :: gradient(:, :)
   !> Strain derivatives of the repulsion energy
   real(wp), contiguous, intent(inout) :: sigma(:, :)

end subroutine get_gradient


pure function variable_info(self) result(info)
   use tblite_scf_info, only : scf_info, atom_resolved, shell_resolved
   !> Instance of the electrostatic container
   class(onsite_thirdorder), intent(in) :: self
   !> Information on the required potential data
   type(scf_info) :: info

   info = scf_info(charge=merge(shell_resolved, atom_resolved, self%shell_resolved))
end function variable_info

end module tblite_coulomb_thirdorder

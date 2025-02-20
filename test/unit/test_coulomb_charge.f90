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

module test_coulomb_charge
   use mctc_env, only : wp
   use mctc_env_testing, only : new_unittest, unittest_type, error_type, check, &
      & test_failed
   use mctc_io, only : structure_type, new
   use mstore, only : get_structure
   use tblite_cutoff, only : get_lattice_points
   use tblite_coulomb_cache, only : coulomb_cache
   use tblite_coulomb_charge, only : effective_coulomb, new_effective_coulomb, &
      & harmonic_average, arithmetic_average
   use tblite_wavefunction_type, only : wavefunction_type
   implicit none
   private

   public :: collect_coulomb_charge

   real(wp), parameter :: cutoff = 25.0_wp
   real(wp), parameter :: thr = 100*epsilon(1.0_wp)
   real(wp), parameter :: thr2 = sqrt(epsilon(1.0_wp))

   abstract interface
      subroutine coulomb_maker(coulomb, mol, shell)
         import :: effective_coulomb, structure_type
         type(effective_coulomb), intent(out) :: coulomb
         type(structure_type), intent(in) :: mol
         logical, intent(in) :: shell
      end subroutine coulomb_maker
   end interface

contains


!> Collect all exported unit tests
subroutine collect_coulomb_charge(testsuite)

   !> Collection of tests
   type(unittest_type), allocatable, intent(out) :: testsuite(:)

   testsuite = [ &
      new_unittest("energy-atom-1", test_e_effective_m01), &
      new_unittest("energy-atom-2", test_e_effective_m02), &
      new_unittest("energy-shell", test_e_effective_m07), &
      new_unittest("energy-atom-pbc", test_e_effective_oxacb), &
      new_unittest("energy-atom-sc", test_e_effective_oxacb_sc), &
      new_unittest("gradient-atom-1", test_g_effective_m03), &
      new_unittest("gradient-atom-2", test_g_effective_m04), &
      new_unittest("gradient-shell", test_g_effective_m08), &
      new_unittest("gradient-atom-pbc", test_g_effective_co2), &
      new_unittest("sigma-atom-1", test_s_effective_m05), &
      new_unittest("sigma-atom-2", test_s_effective_m06), &
      new_unittest("sigma-shell", test_s_effective_m09), &
      new_unittest("sigma-atom-pbc", test_s_effective_ammonia) &
      ]

end subroutine collect_coulomb_charge


!> Factory to create electrostatic objects based on GFN1-xTB values
subroutine make_coulomb1(coulomb, mol, shell)

   !> New electrostatic object
   type(effective_coulomb), intent(out) :: coulomb

   !> Molecular structure data
   type(structure_type), intent(in) :: mol

   !> Return a shell resolved object
   logical, intent(in) :: shell

   real(wp), parameter :: atomic_hardness(20) = [&
      & 0.470099_wp, 1.441379_wp, 0.205342_wp, 0.274022_wp, 0.340530_wp, &
      & 0.479988_wp, 0.476106_wp, 0.583349_wp, 0.788194_wp, 0.612878_wp, &
      & 0.165908_wp, 0.354151_wp, 0.221658_wp, 0.438331_wp, 0.798319_wp, &
      & 0.643959_wp, 0.519712_wp, 0.529906_wp, 0.114358_wp, 0.134187_wp]
   integer, parameter :: shell_count(20) = [&
      & 2, 1, 2, 2, 2, 2, 2, 2, 2, 3, 2, 2, 3, 3, 3, 3, 3, 3, 2, 3]
   real(wp), parameter :: shell_scale(3, 20) = reshape([&
      & 0.0_wp, 0.0000000_wp, 0.0000000_wp,  0.0_wp, 0.0000000_wp, 0.0000000_wp, &
      & 0.0_wp,-0.0772012_wp, 0.0000000_wp,  0.0_wp, 0.1113005_wp, 0.0000000_wp, &
      & 0.0_wp, 0.0165643_wp, 0.0000000_wp,  0.0_wp,-0.0471181_wp, 0.0000000_wp, &
      & 0.0_wp, 0.0315090_wp, 0.0000000_wp,  0.0_wp, 0.0374608_wp, 0.0000000_wp, &
      & 0.0_wp,-0.0827352_wp, 0.0000000_wp,  0.0_wp,-0.3892542_wp, 0.0000000_wp, &
      & 0.0_wp,-0.3004391_wp, 0.0000000_wp,  0.0_wp, 0.0674819_wp, 0.0000000_wp, &
      & 0.0_wp, 0.0503564_wp, 0.0000000_wp,  0.0_wp,-0.5925834_wp, 0.0000000_wp, &
      & 0.0_wp,-0.2530875_wp, 0.0000000_wp,  0.0_wp,-0.1678147_wp, 0.0000000_wp, &
      & 0.0_wp,-0.4481841_wp, 0.0000000_wp,  0.0_wp,-0.1450000_wp, 0.0000000_wp, &
      & 0.0_wp,-0.5332978_wp, 0.0000000_wp,  0.0_wp, 1.1522018_wp, 0.0000000_wp],&
      & shape(shell_scale)) + 1.0_wp
   real(wp), parameter :: gexp = 2.0_wp
   real(wp), allocatable :: hardness(:, :)
   integer :: isp, izp, ish

   if (shell) then
      allocate(hardness(3, mol%nid))
      do isp = 1, mol%nid
         izp = mol%num(isp)
         do ish = 1, shell_count(izp)
            hardness(ish, isp) = atomic_hardness(izp) * shell_scale(ish, izp)
         end do
      end do
      call new_effective_coulomb(coulomb, mol, gexp, hardness, harmonic_average, &
         & shell_count(mol%num))
   else
      hardness = reshape(atomic_hardness(mol%num), [1, mol%nid])
      call new_effective_coulomb(coulomb, mol, gexp, hardness, harmonic_average)
   end if

end subroutine make_coulomb1

!> Factory to create electrostatic objects based on GFN2-xTB values
subroutine make_coulomb2(coulomb, mol, shell)

   !> New electrostatic object
   type(effective_coulomb), intent(out) :: coulomb

   !> Molecular structure data
   type(structure_type), intent(in) :: mol

   !> Return a shell resolved object
   logical, intent(in) :: shell

   real(wp), parameter :: atomic_hardness(20) = [&
      & 0.405771_wp, 0.642029_wp, 0.245006_wp, 0.684789_wp, 0.513556_wp, &
      & 0.538015_wp, 0.461493_wp, 0.451896_wp, 0.531518_wp, 0.850000_wp, &
      & 0.271056_wp, 0.344822_wp, 0.364801_wp, 0.720000_wp, 0.297739_wp, &
      & 0.339971_wp, 0.248514_wp, 0.502376_wp, 0.247602_wp, 0.320378_wp]
   integer, parameter :: shell_count(20) = [&
      & 1, 2, 2, 2, 2, 2, 2, 2, 2, 3, 2, 3, 3, 3, 3, 3, 3, 3, 2, 3]
   real(wp), parameter :: shell_scale(3, 20) = reshape([&
      & 0.0_wp, 0.0000000_wp, 0.0000000_wp, 0.0_wp, 0.0000000_wp, 0.0000000_wp, &
      & 0.0_wp, 0.1972612_wp, 0.0000000_wp, 0.0_wp, 0.9658467_wp, 0.0000000_wp, &
      & 0.0_wp, 0.3994080_wp, 0.0000000_wp, 0.0_wp, 0.1056358_wp, 0.0000000_wp, &
      & 0.0_wp, 0.1164892_wp, 0.0000000_wp, 0.0_wp, 0.1497020_wp, 0.0000000_wp, &
      & 0.0_wp, 0.1677376_wp, 0.0000000_wp, 0.0_wp, 0.1190576_wp,-0.3200000_wp, &
      & 0.0_wp, 0.1018894_wp, 0.0000000_wp, 0.0_wp, 1.4000000_wp,-0.0500000_wp, &
      & 0.0_wp,-0.0603699_wp, 0.2000000_wp, 0.0_wp,-0.5580042_wp,-0.2300000_wp, &
      & 0.0_wp,-0.1558060_wp,-0.3500000_wp, 0.0_wp,-0.1085866_wp,-0.2500000_wp, &
      & 0.0_wp, 0.4989400_wp, 0.5000000_wp, 0.0_wp,-0.0461133_wp,-0.0100000_wp, &
      & 0.0_wp, 0.3483655_wp, 0.0000000_wp, 0.0_wp, 1.5000000_wp,-0.2500000_wp],&
      & shape(shell_scale)) + 1.0_wp
   real(wp), parameter :: gexp = 2.0_wp
   real(wp), allocatable :: hardness(:, :)
   integer :: isp, izp, ish

   if (shell) then
      allocate(hardness(3, mol%nid))
      do isp = 1, mol%nid
         izp = mol%num(isp)
         do ish = 1, shell_count(izp)
            hardness(ish, isp) = atomic_hardness(izp) * shell_scale(ish, izp)
         end do
      end do
      call new_effective_coulomb(coulomb, mol, gexp, hardness, arithmetic_average, &
         & shell_count(mol%num))
   else
      hardness = reshape(atomic_hardness(mol%num), [1, mol%nid])
      call new_effective_coulomb(coulomb, mol, gexp, hardness, arithmetic_average)
   end if

end subroutine make_coulomb2


subroutine test_generic(error, mol, qat, qsh, make_coulomb, ref, thr_in)

   !> Error handling
   type(error_type), allocatable, intent(out) :: error

   !> Molecular structure data
   type(structure_type), intent(inout) :: mol

   !> Atomic partial charges for this structure
   real(wp), intent(in) :: qat(:)

   !> Shell-resolved partial charges for this structure
   real(wp), intent(in), optional :: qsh(:)

   !> Factory to create new electrostatic objects
   procedure(coulomb_maker) :: make_coulomb

   !> Reference value to check against
   real(wp), intent(in) :: ref

   !> Test threshold
   real(wp), intent(in), optional :: thr_in

   integer :: iat, ic
   type(effective_coulomb) :: coulomb
   type(coulomb_cache) :: cache
   real(wp) :: energy, er, el, sigma(3, 3)
   real(wp), allocatable :: gradient(:, :), numgrad(:, :), lattr(:, :)
   real(wp), parameter :: step = 1.0e-6_wp
   real(wp) :: thr_
   type(wavefunction_type) :: wfn

   thr_ = thr
   if (present(thr_in)) thr_ = thr_in

   allocate(gradient(3, mol%nat), numgrad(3, mol%nat))
   energy = 0.0_wp
   gradient(:, :) = 0.0_wp
   sigma(:, :) = 0.0_wp
   if (present(qsh)) then
      wfn%qsh = qsh
   else
      wfn%qsh = qat
   end if
   wfn%qat = qat
   call make_coulomb(coulomb, mol, present(qsh))
   call coulomb%update(mol, cache)
   call coulomb%get_energy(mol, cache, wfn, energy)

   call check(error, energy, ref, thr=thr_)
   if (allocated(error)) then
      print*,ref, energy
   end if

end subroutine test_generic


subroutine test_numgrad(error, mol, qat, qsh, make_coulomb)

   !> Error handling
   type(error_type), allocatable, intent(out) :: error

   !> Molecular structure data
   type(structure_type), intent(inout) :: mol

   !> Atomic partial charges for this structure
   real(wp), intent(in) :: qat(:)

   !> Shell-resolved partial charges for this structure
   real(wp), intent(in), optional :: qsh(:)

   !> Factory to create new electrostatic objects
   procedure(coulomb_maker) :: make_coulomb

   integer :: iat, ic
   type(effective_coulomb) :: coulomb
   type(coulomb_cache) :: cache
   real(wp) :: energy, er, el, sigma(3, 3)
   real(wp), allocatable :: gradient(:, :), numgrad(:, :)
   real(wp), parameter :: step = 1.0e-6_wp
   type(wavefunction_type) :: wfn

   allocate(gradient(3, mol%nat), numgrad(3, mol%nat))
   energy = 0.0_wp
   gradient(:, :) = 0.0_wp
   sigma(:, :) = 0.0_wp
   if (present(qsh)) then
      wfn%qsh = qsh
   else
      wfn%qsh = qat
   end if
   wfn%qat = qat
   call make_coulomb(coulomb, mol, present(qsh))

   do iat = 1, mol%nat
      do ic = 1, 3
         er = 0.0_wp
         el = 0.0_wp
         mol%xyz(ic, iat) = mol%xyz(ic, iat) + step
         call coulomb%update(mol, cache)
         call coulomb%get_energy(mol, cache, wfn, er)
         mol%xyz(ic, iat) = mol%xyz(ic, iat) - 2*step
         call coulomb%update(mol, cache)
         call coulomb%get_energy(mol, cache, wfn, el)
         mol%xyz(ic, iat) = mol%xyz(ic, iat) + step
         numgrad(ic, iat) = 0.5_wp*(er - el)/step
      end do
   end do

   call coulomb%update(mol, cache)
   call coulomb%get_gradient(mol, cache, wfn, gradient, sigma)

   if (any(abs(gradient - numgrad) > thr2)) then
      call test_failed(error, "Gradient of energy does not match")
      print'(3es21.14)', gradient-numgrad
   end if

end subroutine test_numgrad


subroutine test_numsigma(error, mol, qat, qsh, make_coulomb)

   !> Error handling
   type(error_type), allocatable, intent(out) :: error

   !> Molecular structure data
   type(structure_type), intent(inout) :: mol

   !> Atomic partial charges for this structure
   real(wp), intent(in) :: qat(:)

   !> Shell-resolved partial charges for this structure
   real(wp), intent(in), optional :: qsh(:)

   !> Factory to create new electrostatic objects
   procedure(coulomb_maker) :: make_coulomb

   integer :: ic, jc
   type(effective_coulomb) :: coulomb
   type(coulomb_cache) :: cache
   real(wp) :: energy, er, el, sigma(3, 3), eps(3, 3), numsigma(3, 3)
   real(wp), allocatable :: gradient(:, :), xyz(:, :), lattice(:, :)
   real(wp), parameter :: unity(3, 3) = reshape(&
      & [1, 0, 0, 0, 1, 0, 0, 0, 1], shape(unity))
   real(wp), parameter :: step = 1.0e-6_wp
   type(wavefunction_type) :: wfn

   allocate(gradient(3, mol%nat), xyz(3, mol%nat))
   energy = 0.0_wp
   gradient(:, :) = 0.0_wp
   sigma(:, :) = 0.0_wp
   if (present(qsh)) then
      wfn%qsh = qsh
   else
      wfn%qsh = qat
   end if
   wfn%qat = qat
   call make_coulomb(coulomb, mol, present(qsh))

   eps(:, :) = unity
   xyz(:, :) = mol%xyz
   if (any(mol%periodic)) lattice = mol%lattice
   do ic = 1, 3
      do jc = 1, 3
         er = 0.0_wp
         el = 0.0_wp
         eps(jc, ic) = eps(jc, ic) + step
         mol%xyz(:, :) = matmul(eps, xyz)
         if (allocated(lattice)) mol%lattice(:, :) = matmul(eps, lattice)
         call coulomb%update(mol, cache)
         call coulomb%get_energy(mol, cache, wfn, er)
         eps(jc, ic) = eps(jc, ic) - 2*step
         mol%xyz(:, :) = matmul(eps, xyz)
         if (allocated(lattice)) mol%lattice(:, :) = matmul(eps, lattice)
         call coulomb%update(mol, cache)
         call coulomb%get_energy(mol, cache, wfn, el)
         eps(jc, ic) = eps(jc, ic) + step
         mol%xyz(:, :) = xyz
         if (allocated(lattice)) mol%lattice = lattice
         numsigma(jc, ic) = 0.5_wp*(er - el)/step
      end do
   end do

   call coulomb%update(mol, cache)
   call coulomb%get_gradient(mol, cache, wfn, gradient, sigma)

   if (any(abs(sigma - numsigma) > thr2)) then
      call test_failed(error, "Strain derivatives do not match")
      print'(3es21.14)', sigma-numsigma
   end if

end subroutine test_numsigma


subroutine test_e_effective_m01(error)

   !> Error handling
   type(error_type), allocatable, intent(out) :: error

   type(structure_type) :: mol
   real(wp), parameter :: qat(*) = [&
      & 7.73347900345264E-1_wp, 1.07626888948184E-1_wp,-3.66999593831010E-1_wp,&
      & 4.92833325937897E-2_wp,-1.83332156197733E-1_wp, 2.33302086605469E-1_wp,&
      & 6.61837152062315E-2_wp,-5.43944165050002E-1_wp,-2.70264356583716E-1_wp,&
      & 2.66618968841682E-1_wp, 2.62725033202480E-1_wp,-7.15315510172571E-2_wp,&
      &-3.73300777019193E-1_wp, 3.84585237785621E-2_wp,-5.05851088366940E-1_wp,&
      & 5.17677238544189E-1_wp]
   real(wp), allocatable :: qsh(:)

   call get_structure(mol, "MB16-43", "01")
   call test_generic(error, mol, qat, qsh, make_coulomb1, 0.10952019883948200_wp)

end subroutine test_e_effective_m01


subroutine test_e_effective_m02(error)

   !> Error handling
   type(error_type), allocatable, intent(out) :: error

   type(structure_type) :: mol
   real(wp), parameter :: qat(*) = [&
      & 7.38394711236234E-2_wp,-1.68354976558608E-1_wp,-3.47642833746823E-1_wp,&
      &-7.05489267186003E-1_wp, 7.73548301641266E-1_wp, 2.30207581365386E-1_wp,&
      & 1.02748501676354E-1_wp, 9.47818107467040E-2_wp, 2.44260351729187E-2_wp,&
      & 2.34984927037408E-1_wp,-3.17839896393030E-1_wp, 6.67112994818879E-1_wp,&
      &-4.78119977010488E-1_wp, 6.57536027459275E-2_wp, 1.08259054549882E-1_wp,&
      &-3.58215329983396E-1_wp]
   real(wp), allocatable :: qsh(:)

   call get_structure(mol, "MB16-43", "02")
   call test_generic(error, mol, qat, qsh, make_coulomb2, 0.10635843572138280_wp)

end subroutine test_e_effective_m02


subroutine test_e_effective_oxacb(error)

   !> Error handling
   type(error_type), allocatable, intent(out) :: error

   type(structure_type) :: mol
   real(wp), parameter :: qat(*) = [&
      & 3.41731844312030E-1_wp, 3.41716020106239E-1_wp, 3.41730526585671E-1_wp,&
      & 3.41714427217954E-1_wp, 3.80996046757999E-1_wp, 3.80989821246195E-1_wp,&
      & 3.81000747720282E-1_wp, 3.80990494183703E-1_wp,-3.70406587264474E-1_wp,&
      &-3.70407565207006E-1_wp,-3.70417590212352E-1_wp,-3.70399716470705E-1_wp,&
      &-3.52322260586075E-1_wp,-3.52304269439196E-1_wp,-3.52313440903261E-1_wp,&
      &-3.52298498047004E-1_wp]
   real(wp), allocatable :: qsh(:)

   call get_structure(mol, "X23", "oxacb")
   call test_generic(error, mol, qat, qsh, make_coulomb2, 0.10130450083781417_wp)

end subroutine test_e_effective_oxacb


subroutine test_e_effective_oxacb_sc(error)

   !> Error handling
   type(error_type), allocatable, intent(out) :: error

   type(structure_type) :: mol
   real(wp), parameter :: qat1(*) = [&
      & 3.41731844312030E-1_wp, 3.41716020106239E-1_wp, 3.41730526585671E-1_wp,&
      & 3.41714427217954E-1_wp, 3.80996046757999E-1_wp, 3.80989821246195E-1_wp,&
      & 3.81000747720282E-1_wp, 3.80990494183703E-1_wp,-3.70406587264474E-1_wp,&
      &-3.70407565207006E-1_wp,-3.70417590212352E-1_wp,-3.70399716470705E-1_wp,&
      &-3.52322260586075E-1_wp,-3.52304269439196E-1_wp,-3.52313440903261E-1_wp,&
      &-3.52298498047004E-1_wp]
   integer, parameter :: supercell(*) = [2, 2, 2]
   real(wp), parameter :: qat(*) = [spread(qat1, 2, product(supercell))]
   real(wp), allocatable :: qsh(:)

   call get_structure(mol, "X23", "oxacb")
   call make_supercell(mol, supercell)
   call test_generic(error, mol, qat, qsh, make_coulomb2, &
      & 0.10130450083781417_wp*product(supercell), 1.0e-7_wp)

end subroutine test_e_effective_oxacb_sc


subroutine make_supercell(mol, rep)
   type(structure_type), intent(inout) :: mol
   integer, intent(in) :: rep(3)

   real(wp), allocatable :: xyz(:, :), lattice(:, :)
   integer, allocatable :: num(:)
   integer :: i, j, k, c

   num = reshape(spread([mol%num(mol%id)], 2, product(rep)), [product(rep)*mol%nat])
   lattice = reshape(&
      [rep(1)*mol%lattice(:, 1), rep(2)*mol%lattice(:, 2), rep(3)*mol%lattice(:, 3)], &
      shape(mol%lattice))
   allocate(xyz(3, product(rep)*mol%nat))
   c = 0
   do i = 0, rep(1)-1
      do j = 0, rep(2)-1
         do k = 0, rep(3)-1
            xyz(:, c+1:c+mol%nat) = mol%xyz &
               & + spread(matmul(mol%lattice, [real(wp):: i, j, k]), 2, mol%nat)
            c = c + mol%nat
         end do
      end do
   end do

   call new(mol, num, xyz, lattice=lattice)
end subroutine make_supercell


subroutine test_g_effective_m03(error)

   !> Error handling
   type(error_type), allocatable, intent(out) :: error

   type(structure_type) :: mol
   real(wp), parameter :: qat(*) = [&
      &-1.77788256288236E-1_wp,-8.22943267808161E-1_wp, 4.04578389873281E-2_wp,&
      & 5.79710531992282E-1_wp, 6.99601887637659E-1_wp, 6.84309612639107E-2_wp,&
      &-3.42971414989811E-1_wp, 4.64954031865410E-2_wp, 6.77012204116428E-2_wp,&
      & 8.49931225363225E-2_wp,-5.22285304699699E-1_wp,-2.92515001764712E-1_wp,&
      &-3.98375452377043E-1_wp, 2.09769668297792E-1_wp, 7.23140464830357E-1_wp,&
      & 3.65775987838250E-2_wp]
   real(wp), allocatable :: qsh(:)

   call get_structure(mol, "MB16-43", "03")
   call test_numgrad(error, mol, qat, qsh, make_coulomb1)

end subroutine test_g_effective_m03


subroutine test_g_effective_m04(error)

   !> Error handling
   type(error_type), allocatable, intent(out) :: error

   type(structure_type) :: mol
   real(wp), parameter :: qat(*) = [&
      & 9.33596160193497E-2_wp,-3.41088061922851E-1_wp, 7.32474961830646E-2_wp,&
      &-2.21649975471802E-1_wp, 6.24413528413759E-3_wp, 1.07366683260668E-1_wp,&
      & 1.25982547197317E-1_wp, 9.65935501843890E-2_wp, 1.02704543049803E-1_wp,&
      & 1.45380937882263E-1_wp,-1.55978251071729E-1_wp, 3.42948437914661E-1_wp,&
      & 5.65504846503244E-2_wp,-3.37789986050220E-1_wp, 1.13510089629769E-1_wp,&
      &-2.07382246739143E-1_wp]
   real(wp), allocatable :: qsh(:)

   call get_structure(mol, "MB16-43", "04")
   call test_numgrad(error, mol, qat, qsh, make_coulomb2)

end subroutine test_g_effective_m04


subroutine test_g_effective_co2(error)

   !> Error handling
   type(error_type), allocatable, intent(out) :: error

   type(structure_type) :: mol
   real(wp), parameter :: qat(*) = [&
      & 4.56275672862067E-1_wp, 4.56284770386671E-1_wp, 4.56284770386671E-1_wp,&
      & 4.56284770386671E-1_wp,-2.28127680925611E-1_wp,-2.28138283131909E-1_wp,&
      &-2.28145770512561E-1_wp,-2.28145770512561E-1_wp,-2.28150142163058E-1_wp,&
      &-2.28145770512561E-1_wp,-2.28138283131909E-1_wp,-2.28138283131909E-1_wp]
   real(wp), allocatable :: qsh(:)

   call get_structure(mol, "X23", "CO2")
   call test_numgrad(error, mol, qat, qsh, make_coulomb2)

end subroutine test_g_effective_co2


subroutine test_s_effective_m05(error)

   !> Error handling
   type(error_type), allocatable, intent(out) :: error

   type(structure_type) :: mol
   real(wp), parameter :: qat(*) = [&
      &-2.01138111283277E-1_wp, 1.30358706339300E-1_wp, 9.38825924720944E-2_wp,&
      & 8.92795900801844E-2_wp, 5.13625440660610E-2_wp,-2.65500121876709E-2_wp,&
      & 9.26496972837658E-2_wp,-9.61095258223972E-2_wp,-4.92845009674246E-1_wp,&
      & 2.66730531684206E-1_wp, 3.37256104303071E-2_wp, 1.63170419985976E-1_wp,&
      & 6.91343155032824E-2_wp, 1.04287482572171E-1_wp, 6.09307909835941E-2_wp,&
      &-3.38869622433350E-1_wp]
   real(wp), allocatable :: qsh(:)

   call get_structure(mol, "MB16-43", "05")
   call test_numsigma(error, mol, qat, qsh, make_coulomb1)

end subroutine test_s_effective_m05


subroutine test_s_effective_m06(error)

   !> Error handling
   type(error_type), allocatable, intent(out) :: error

   type(structure_type) :: mol
   real(wp), parameter :: qat(*) = [&
      &-2.13983049532933E-1_wp,-5.10521279217923E-1_wp, 7.70190120699491E-2_wp,&
      &-3.68835155548212E-1_wp,-4.08747874260092E-1_wp,-4.09471309598929E-2_wp,&
      & 2.94164204769172E-1_wp, 9.76819709672870E-2_wp,-7.84337476935767E-3_wp,&
      & 7.07702520795024E-1_wp, 2.38774840136381E-1_wp, 1.08934666297455E-1_wp,&
      & 1.10156911889136E-1_wp, 9.25098455002779E-2_wp,-1.96776817442259E-1_wp,&
      & 2.07107093059868E-2_wp]
   real(wp), allocatable :: qsh(:)

   call get_structure(mol, "MB16-43", "06")
   call test_numsigma(error, mol, qat, qsh, make_coulomb2)

end subroutine test_s_effective_m06


subroutine test_s_effective_ammonia(error)

   !> Error handling
   type(error_type), allocatable, intent(out) :: error

   type(structure_type) :: mol
   real(wp), parameter :: qat(*) = [&
      & 2.95376975876519E-1_wp, 2.95376975876519E-1_wp, 2.95376975876519E-1_wp,&
      & 2.95329109335847E-1_wp, 2.95332441468412E-1_wp, 2.95347202855778E-1_wp,&
      & 2.95347202855779E-1_wp, 2.95329109335848E-1_wp, 2.95332441468411E-1_wp,&
      & 2.95347202855777E-1_wp, 2.95329109335847E-1_wp, 2.95332441468412E-1_wp,&
      &-8.86118742099358E-1_wp,-8.86012815503436E-1_wp,-8.86012815503437E-1_wp,&
      &-8.86012815503434E-1_wp]
   real(wp), allocatable :: qsh(:)

   call get_structure(mol, "X23", "ammonia")
   call test_numsigma(error, mol, qat, qsh, make_coulomb2)

end subroutine test_s_effective_ammonia

subroutine write_charges(mol)
   use dftd4_charge, only : get_charges
   type(structure_type) :: mol
   real(wp), allocatable :: qat(:)
   allocate(qat(mol%nat))
   call get_charges(mol, qat)
   write(*, '(3x,a)') "real(wp), parameter :: qat(*) = [&"
   write(*, '(*(6x,"&",3(es20.14e1, "_wp":, ","),"&", /))', advance='no') qat
   write(*, '(a)') "]"
end subroutine

subroutine test_e_effective_m07(error)

   !> Error handling
   type(error_type), allocatable, intent(out) :: error

   type(structure_type) :: mol
   real(wp), parameter :: qat(*) = [&
      &-1.49712318034775E-1_wp, 2.12665850975202E-1_wp, 3.35977061494489E-1_wp, &
      & 3.16737890491354E-2_wp, 4.12434432866631E-2_wp,-3.21014009885608E-1_wp, &
      &-3.06535419089495E-1_wp,-5.36251066565321E-1_wp, 4.48758364798896E-1_wp, &
      & 6.00309584480896E-2_wp,-2.75470557482709E-1_wp, 3.60263594022551E-1_wp, &
      & 3.77425314022796E-1_wp,-6.30561365518420E-1_wp,-2.50675164323255E-1_wp, &
      & 6.02181524801775E-1_wp]
   real(wp), parameter :: qsh(*) = [&
      & 8.85960229060055E-1_wp,-1.03567241653662E+0_wp, 2.34499192077770E-1_wp, &
      &-2.18333480864186E-2_wp, 1.09026104661485E+0_wp,-7.54283954798938E-1_wp, &
      & 4.12740327203921E-2_wp,-9.60021563849638E-3_wp, 5.17672944681095E-2_wp, &
      &-1.05238375989861E-2_wp, 5.94332546515988E-2_wp,-3.94897989828280E-1_wp, &
      & 1.44506731071946E-2_wp, 1.57870128213110E-1_wp,-4.64405557396352E-1_wp, &
      & 4.78122334280047E-1_wp,-1.01437364107707E+0_wp, 9.10337331767967E-1_wp, &
      &-4.61579000227231E-1_wp, 9.07619848805192E-2_wp,-3.07310018122722E-2_wp, &
      & 1.13955875471381E-1_wp,-3.99913576087036E-1_wp, 1.04872002787662E-2_wp, &
      & 4.12951024314537E-1_wp,-5.26874026571100E-2_wp, 4.04435991881125E-1_wp, &
      &-2.70107073714884E-2_wp, 3.13675308978710E-1_wp,-9.44236655190031E-1_wp, &
      & 1.75329569882602E-1_wp,-4.26004749886597E-1_wp, 1.24860566181157E+0_wp, &
      &-6.46424080267374E-1_wp]

   call get_structure(mol, "MB16-43", "07")
   call test_generic(error, mol, qat, qsh, make_coulomb1, 0.12017418620257683_wp)

end subroutine test_e_effective_m07

subroutine test_g_effective_m08(error)

   !> Error handling
   type(error_type), allocatable, intent(out) :: error

   type(structure_type) :: mol
   real(wp), parameter :: qat(*) = [&
      &-2.11048312695985E-1_wp,-5.02011645803230E-1_wp, 4.15238062649689E-1_wp, &
      &-3.25959600753673E-1_wp, 2.51473641195433E-2_wp, 2.93748490123740E-1_wp, &
      & 2.56736194030896E-2_wp, 2.38762690307426E-2_wp,-6.03118603733083E-1_wp, &
      & 3.91990240426822E-1_wp, 8.97114734113785E-1_wp, 1.93532936362436E-1_wp, &
      &-1.03136268223866E-1_wp,-1.04447608767710E-1_wp,-2.64818891498402E-2_wp, &
      &-3.90117787102468E-1_wp]
   real(wp), parameter :: qsh(*) = [&
      & 9.06259904944829E-1_wp,-1.11730821567902E+0_wp, 2.78017329305492E-1_wp, &
      &-7.80028989546297E-1_wp, 1.11352815063389E+0_wp,-6.98290073981154E-1_wp, &
      & 2.03943236255318E-1_wp,-5.29902840441233E-1_wp, 4.38219939650397E-2_wp, &
      &-1.86746328945826E-2_wp, 4.65996457236599E-2_wp, 4.97590807484258E-1_wp, &
      &-2.50441962186972E-1_wp, 4.83295451755440E-2_wp,-2.26559244782012E-2_wp, &
      & 4.50331992744248E-2_wp,-2.11569328297532E-2_wp, 3.12470620007346E-1_wp, &
      &-9.15589243372491E-1_wp, 1.06394261835743E+0_wp,-6.71952361588756E-1_wp, &
      & 1.82322476598938E+0_wp,-9.26110009158329E-1_wp, 9.78357111140355E-1_wp, &
      &-7.84824170464332E-1_wp,-9.43549308434806E-2_wp,-8.78133979988158E-3_wp, &
      &-7.07783143624696E-2_wp,-3.36692984665466E-2_wp, 6.75375129657761E-1_wp, &
      &-7.01857024422455E-1_wp, 2.11598132242645E-1_wp,-6.01715925641418E-1_wp]

   call get_structure(mol, "MB16-43", "08")
   call test_numgrad(error, mol, qat, qsh, make_coulomb1)

end subroutine test_g_effective_m08

subroutine test_s_effective_m09(error)

   !> Error handling
   type(error_type), allocatable, intent(out) :: error

   type(structure_type) :: mol
   real(wp), parameter :: qat(*) = [&
      &-1.13260038539900E-2_wp, 1.10070523471231E-2_wp,-9.97165474630829E-2_wp, &
      &-8.78527301724521E-2_wp, 2.89049242695863E-1_wp, 3.57284006856323E-2_wp, &
      &-1.73226219187217E-1_wp, 1.61174372420268E-1_wp,-8.89089419183055E-2_wp, &
      & 3.23950178196666E-2_wp, 1.88420688366637E-1_wp, 4.14882523279327E-2_wp, &
      &-2.23498403532295E-1_wp,-3.55334728213004E-1_wp,-7.15753987897201E-2_wp, &
      & 3.52175946466941E-1_wp]
   real(wp), parameter :: qsh(*) = [&
      & 1.40887956776581E-3_wp,-1.27348820058716E-2_wp, 2.63961183739554E-2_wp, &
      &-1.53890176131402E-2_wp,-8.73648546608390E-2_wp,-1.23517435478204E-2_wp, &
      &-8.71021014527735E-2_wp,-7.50559382736492E-4_wp, 7.82044211296174E-1_wp, &
      &-4.92995083533018E-1_wp, 4.84143136555792E-2_wp,-1.26858387490357E-2_wp, &
      & 9.72488073646510E-1_wp,-1.14571448042039E+0_wp, 1.07574874045191E+0_wp, &
      &-9.14574293473561E-1_wp,-7.63358458276189E-2_wp,-1.25730981035572E-2_wp, &
      & 4.44349073468088E-2_wp,-1.20397879426510E-2_wp, 5.20245311277456E-1_wp, &
      & 1.92282483805197E-1_wp,-5.24107355799204E-1_wp, 5.39382871928999E-2_wp, &
      &-1.24499232808976E-2_wp, 7.97368410133983E-2_wp,-3.13209082796440E-1_wp, &
      & 9.97387287057362E-3_wp, 1.94446888375020E-1_wp,-5.49781435696375E-1_wp, &
      &-6.89789344411558E-2_wp,-2.59643153694089E-3_wp, 1.09519797601190E+0_wp, &
      &-7.43022154621128E-1_wp]

   call get_structure(mol, "MB16-43", "09")
   call test_numsigma(error, mol, qat, qsh, make_coulomb1)

end subroutine test_s_effective_m09

end module test_coulomb_charge

/* This file is part of tblite.
 * SPDX-Identifier: LGPL-3.0-or-later
 *
 * tblite is free software: you can redistribute it and/or modify it under
 * the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * tblite is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with tblite.  If not, see <https://www.gnu.org/licenses/>.
**/

#pragma once

#include "tblite/macros.h"
#include "tblite/context.h"
#include "tblite/structure.h"
#include "tblite/result.h"
#include "tblite/param.h"

/// Single point calculator
typedef struct _tblite_calculator* tblite_calculator;

/// Construct calculator with GFN2-xTB parametrisation loaded
TBLITE_API_ENTRY tblite_calculator TBLITE_API_CALL
tblite_new_gfn2_calculator(tblite_context /* ctx */,
                           tblite_structure /* mol */);

/// Construct calculator with GFN1-xTB parametrisation loaded
TBLITE_API_ENTRY tblite_calculator TBLITE_API_CALL
tblite_new_gfn1_calculator(tblite_context /* ctx */,
                           tblite_structure /* mol */);

/// Construct calculator with IPEA1-xTB parametrisation loaded
TBLITE_API_ENTRY tblite_calculator TBLITE_API_CALL
tblite_new_ipea1_calculator(tblite_context /* ctx */,
                            tblite_structure /* mol */);

/// Construct calculator from parametrization records
TBLITE_API_ENTRY tblite_calculator TBLITE_API_CALL
tblite_new_xtb_calculator(tblite_context /* ctx */,
                          tblite_structure /* mol */,
                          tblite_param /* param */);

/// Delete calculator
TBLITE_API_ENTRY void TBLITE_API_CALL
tblite_delete_calculator(tblite_calculator* /* calc */);

/// Set calculation accuracy for the calculator object
TBLITE_API_ENTRY void TBLITE_API_CALL
tblite_set_calculator_accuracy(tblite_context /* ctx */,
                               tblite_calculator /* calc */,
                               double /* acc */);

/// Set maximum number of allowed iterations in calculator object
TBLITE_API_ENTRY void TBLITE_API_CALL
tblite_set_calculator_max_iter(tblite_context /* ctx */,
                               tblite_calculator /* calc */,
                               int /* max_iter */);

/// Set parameter for mixier in calculator object
TBLITE_API_ENTRY void TBLITE_API_CALL
tblite_set_calculator_mixer_damping(tblite_context /* ctx */,
                                    tblite_calculator /* calc */,
                                    double /* damping */);

/// Set electronic temperature for the calculator object (in Hartree)
TBLITE_API_ENTRY void TBLITE_API_CALL
tblite_set_calculator_temperature(tblite_context /* ctx */,
                                  tblite_calculator /* calc */,
                                  double /* etemp */);

/// Perform single point calculation
TBLITE_API_ENTRY tblite_calculator TBLITE_API_CALL
tblite_get_singlepoint(tblite_context /* ctx */,
                       tblite_structure /* mol */,
                       tblite_calculator /* calc */,
                       tblite_result /* res */);

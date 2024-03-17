// attribution: following code is used from the old Ringo package
// https://www.bioconductor.org/packages/release/bioc/src/contrib/Ringo_1.66.0.tar.gz

// initialization of the package

#include "Repitools.h"

#include <R.h>
#include <Rdefines.h>
#include <Rinternals.h>
#include <R_ext/Rdynload.h>

static R_CallMethodDef Ringo_calls[] = {
  {"moving_mean_sd", (DL_FUNC) &moving_mean_sd, 3},
  // necessary last entry of R_CallMethodDef:
  {NULL, NULL, 0}
};


// attribution: following code is used from the old Ringo package
// https://www.bioconductor.org/packages/release/bioc/src/contrib/Ringo_1.66.0.tar.gz


#include <algorithm>
#include <cmath>

// R headers, moved outside "extern C" in v1.35.1
#include <R.h>
#include <Rdefines.h>
#include <Rinternals.h>
#include <R_ext/Error.h>
#include <R_ext/Rdynload.h>
#include <R_ext/Utils.h>


using namespace std;
// the above stuff is pure C++, thus needs to be outside the 'extern "C"'

extern "C" {

/* This function compute the mean and sd within a sliding window.
   given one set of position and an according set of values and
   (half of) the size of the window.
   Therefore the number of points inside the window is returned in addition
   to the mean and sd values.

   Written by Joern Toedling and Oleg Sklyar, March 2008.
*/

SEXP
moving_mean_sd(SEXP ind, SEXP val, SEXP hlfsize) {
    int * x, nval, hs, is, i;
    double * y, * rval;
    int nprotect = 0;
    int valcount = 0;
    double sumval = 0.0;
    double sumsquareval = 0.0;
    double avg = 0;
    double s_dev = 0;
    int first = 0, last = -1;

    SEXP res, dim;
    x = INTEGER(ind);
    y = REAL(val);
    hs = INTEGER(hlfsize)[0];
    nval = LENGTH(ind);

    PROTECT( res = allocVector( REALSXP, nval * 3) );
    nprotect++;

    rval = REAL(res);

    for (i = 0; i < nval * 3; i++)
        rval[i] = R_NaN;

    // we assume indexes, and therefore x, to be in accending order!
    // iterate over all positions, center the sliding window at position i:
    for (i = 0; i < nval; i++ ) {

      /* see if due to moving the window, values at left side are dropped
      can be dropped window since they are more than half.width hs distant: */
      while ( first <= last && x[first] < x[i] - hs){
        sumval -= y[first];
        sumsquareval -= pow(y[first], 2.0);
        valcount--;
        first++;
      }
      /* see if due to moving window, values at right side should be appended
      can be dropped window since they are more than half.width hs distant: */
      while ( x[last + 1] <= x[i] + hs && last < nval - 1) {
        last++;
        sumval += y[last];
        sumsquareval += pow(y[last], 2.0);
        valcount++;
      }

      is = last - first + 1;
      // number of positions
      // if ( is == valcount) continue; // if something went wrong

      avg = sumval / valcount;

      if (valcount == 1) {
        s_dev = 0;
      } else {
        s_dev = sqrt( (valcount*sumsquareval - pow(sumval,2.0)) / (valcount*(valcount-1)) );
       }
      rval[i] = avg;
      rval[i + nval] = s_dev;
      rval[i + 2*nval] = valcount;

    }
    // set the dimensions of the result: it's an array with number of
    //  positions rows and three columns
    PROTECT( dim = allocVector(INTSXP, 2));
    nprotect++;
    INTEGER(dim)[0] = nval;
    INTEGER(dim)[1] = 3;
    SET_DIM(res, dim);

    // do not need to protect objects from R's garbage collector any longer
    UNPROTECT(nprotect);
    return res;
}

}// extern C


BEGIN {print "#!/bin/bash"}
$1 !~/#/ && 0 < $2 {print "fslmaths " niftifile " -thr " $2 " -uthr " $2, hemi "." tolower($5)".nii.gz" }

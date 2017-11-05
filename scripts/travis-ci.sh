#!/bin/bash

set -e

travis_nanoseconds() {
  local cmd="date"
  local format="+%s%N"
  local os=$(uname)

  $cmd -u $format
}

travis_start() {
  travis_timer_id=$(printf %08x $(( RANDOM * RANDOM )))
  travis_start_time=$(travis_nanoseconds)
  echo -e "travis_time:start:$travis_timer_id\r\e[0m$1"
  echo -e "travis_fold:start:$2\n$1"
}

travis_finish() {
  echo "travis_fold:end:$1"
  local result=$?
  travis_end_time=$(travis_nanoseconds)
  local duration=$(($travis_end_time-$travis_start_time))
  echo -en "\ntravis_time:end:$travis_timer_id:start=$travis_start_time,finish=$travis_end_time,duration=$duration\r\e[0m"
  return $result
}

travis_start "Building OpenSCAD using qmake" qmake
qmake CONFIG+=experimental CONFIG+=nogui && make -j2
travis_finish qmake

travis_start "Building tests using cmake" cmake

cd tests
cmake . 
if [[ $? != 0 ]]; then
  echo "Error configuring test suite"
  exit 1
fi
make -j2
if [[ $? != 0 ]]; then
  echo "Error building test suite"
  exit 1
fi

travis_finish cmake

if [[ "$DIST" == "trusty" ]]; then
    PARALLEL=-j1
else
    PARALLEL=-j8
fi

travis_start "Running tests using ctest" ctest

# Exclude tests known the cause issues on Travis
# opencsgtest_rotate_extrude-tests - Fails on Ubuntu 12.04 using Gallium 0.4 drivers
# *_text-font-direction-tests - Fails due to old freetype (issue #899)
# throwntogethertest_issue964 - Fails due to non-planar quad being tessellated slightly different
# opencsgtest_issue1165 - z buffer tearing

# Fails on Apple's software renderer:
# opencsgtest_issue1258
# throwntogethertest_issue1089
# throwntogethertest_issue1215
ctest $PARALLEL -E "\
opencsgtest_rotate_extrude-tests|\
opencsgtest_render-tests|\
opencsgtest_rotate_extrude-hole|\
opencsgtest_internal-cavity|\
opencsgtest_internal-cavity-polyhedron|\
opencsgtest_minkowski3-erosion|\
opencsgtest_issue835|\
opencsgtest_issue911|\
opencsgtest_issue913|\
opencsgtest_issue1215|\
opencsgtest_issue1105d|\
dxfpngtest_text-font-direction-tests|\
cgalpngtest_text-font-direction-tests|\
opencsgtest_text-font-direction-tests|\
csgpngtest_text-font-direction-tests|\
svgpngtest_text-font-direction-tests|\
throwntogethertest_text-font-direction-tests|\
throwntogethertest_issue964|\
opencsgtest_issue1165|\
opencsgtest_issue1258|\
throwntogethertest_issue1089|\
throwntogethertest_issue1215\
"
if [[ $? != 0 ]]; then
  echo "Test failure"
  exit 1
fi

travis_finish ctest

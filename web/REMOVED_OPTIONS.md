# Options excluded from web UI

These processGPX options are intentionally excluded from the web UI.
They remain available via the command-line tool.

## Not applicable to web UI

These options control CLI behavior that has no meaning in the web
context (file selection, output control, terminal output).

- `csv` — output CSV instead of GPX; web UI always returns GPX
- `help` / `h` — print help and exit
- `join` — append points from another GPX file; web UI accepts one file
- `noSave` — suppress output file; web UI always needs output
- `out` / `o` — specify output filename; web UI controls this
- `quiet` — suppress stderr messages; no stderr in web UI
- `splice` — replace segments with points from another file; requires multiple files
- `spliceDistance` — distance tolerance for splicing; not applicable without `splice`
- `version` / `v` — print version and exit; version shown in footer

## Undocumented/internal options

These options exist in the Perl script but are not documented in the
help text, suggesting they are internal or experimental.

- `addDistance` — adds a distance extension field (commented as undocumented in script)
- `lAutoSmooth` — lateral auto-smoothing (commented as undocumented in script;
  `autoSmoothL` is an alias)

## Aliases

The Perl script accepts many aliases for options. Only the canonical
name is shown in the web UI. Aliases omitted include: `align`,
`autoSmoothL`,
`alignAltitude`, `alignDistance`, `alignTransition`, `alignZ`,
`arcFit`, `arcInterpolationMaxAngle`, `autoLap`, `circleStop`, `circuitFromPoint`,
`circuitToPoint`, `circuitsFromPoint`, `circuitsFromPosition`,
`circuitsToPoint`, `circuitsToPosition`, `closed`, `closedLoop`, `crop`,
`cropCorners`, `cropEnd`, `cropStart`, `cropStop`, `finishCircuitStart`,
`fitArcsAngle`, `gAutoSmooth`, `gSigma`, `gSmooth`, `interpolate`,
`laneShiftEnd`, `laneShiftSF`, `laneShiftStart`, `laneShiftTransition`,
`lap`, `loopL`, `loopR`, `maxCornerCropAngle`, `minCornerCropAngle`,
`outAndBackLoop`, `pruneDistance`, `pruneGradient`, `pruneSine`,
`segments`, `selectiveGSmooth`, `selectiveZSmooth`, `shiftX`, `shiftY`,
`shiftZ`, `shiftZEnd`, `shiftZStart`, `sigma`, `sigmag`, `sigmaz`,
`simplify`, `simplifyAltitude`, `simplifyDistance`, `smoothing`, `snapZ`,
`splineAngle`, `splineMaxAngle`, `startCircuitEnd`, `straightStop`,
`title`, `zAutoSmooth`, `zScaleReference`, `zSigma`, `zSmooth`.

## Secondary output files

These options generate additional output files on the server filesystem,
which is not useful in the web UI (it returns a single processed GPX).

- `saveCrossingsCSV` — writes a `_crossings.csv` file with crossing coordinates
- `saveSimplifiedCourse` — writes a `_simplifiedCourse.csv` for debugging

## Splits (multiple output files)

These options split the route into multiple output files. The web UI
returns a single processed GPX file.

- `autoSplits` — automatically divide route into N equal parts
- `splitAt` — split route at specified distances
- `splitNumber` — select which split to output
- `timeSplits` — split route into portions based on estimated ride time

## Segments (RGT-specific, no current application)

The documentation states these were "designed for use in RGT and has no
application in any present program other than GPXMagic." The `segment`
option is also described as "RGT-specific... it thus serves no purpose."

- `autoSegmentFinishMargin` — buffer between segment and finish banner
- `autoSegmentMargin` — buffer between auto-generated segments
- `autoSegmentNames` — custom names for auto-segments
- `autoSegmentPower` — gradient power for rating climbs
- `autoSegmentStartMargin` — buffer from start banner
- `autoSegmentStretch` — distance increase to reach true peaks
- `autoSegments` — enable auto-segmentation with threshold
- `segment` — define named segments manually
- `stripSegments` — remove existing segment definitions

## RGT-specific options

These options were designed for the now-defunct RGT platform and have
limited or no utility with current platforms like BikeTerra.

- `extendBack` — creates turnaround at end; doc says "will likely generate
  undesirable results with BikeTerra"
- `maxSlope` — RGT maximum slope; removed from processGPX in v0.65

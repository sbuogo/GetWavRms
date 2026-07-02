GetWavRms

Matlab (R) script to obtain RMS values of audio waveforms contained in WAV format files.

Originally designed to be used for calibration of digital audio recorders by comparison with a reference device, 
using a gated pulse-echo technique to reproduce free-field conditions.
To this aim, the script accepts either one (H, recorder under test) or two (H and Ref, reference recorder) 
files in WAV format, sequentially takes selected portions containing one or more repeat pulse(s) 
with each frequency, optionally filters each portion (high-pass or band-pass), finds cross-correlation peaks with 
one selected pulse to align and overlap in time all repeat pulses, then computes average RMS in a user-selected time gate.
If two input files are chosen, the same sequence is repeated on both files with equal time alignment of pulses.

Send comments to  Silvano Buogo  silvano.buogo@cnr.it

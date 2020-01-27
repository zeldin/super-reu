NAME
====

`m64conv` - converts movies for C64 fullscreen playback


SYNOPSIS
========

`mc64conv` [`-f` _fps_] [`-r` _rate_] [`-v` _volume_] [`-m`] [`-n`] [`-d` _size_] [`-p`] [`-j` _number_] _videofile_ [_audiofile_] `>` _destination_


DESCRIPTION
===========

Converts audio and video from any format that is recognized by `ffmpeg`
(including separate PNG files for each frame) to the `m64` format.
The converted data is output to stdout, and should be redirected to a file.
The `ffmpeg` command line binary must be present in `$PATH`.

If no separate audiofile is specified, audio is taken from the videofile.


Options
-------

`-f` _fps_

   Number of frames per second in the input movie

   The converter will skip or duplicate frames as needed to reach the
   target rate of 50 (60) frames per second.

`-r` _rate_

   Target audio samples per second

   Audio will be resampled to this rate during conversion.  The valid
   range is 5000-48000 Hz, but note that rates over 16000 Hz will not
   work well due to badlines.  Rates of 12000 Hz and below result in
   all audio data fitting within the header block (file size is unaffected
   by audio).  The default target audio sample rate is 16000 Hz.

`-v` _volume_

   Volume gain

   If specified, the input volume will be multiplied by this number.
   Output values are clipped to the maximum value.

`-m`

   Enable multicolor mode

`-n`

   Target NTSC (60 Hz) C64:s

   This will make the target rate 60 frames per second.

`-d` _size_

   Set dithering size

   A _size_ larger than 0 enables dithering with dots of the specified
   size.  Size 2 is recommended for multicolor mode.

`-p`

   Enables a preview window with the converted video

   The command `fflplay` must be available.  No audio preview is available.

`-j` _number_

   Sets number of threads for multithreaded video encoding

   Default is to use one thread for video encoding.  Note that video
   _decoding_ always happens in a separate process.


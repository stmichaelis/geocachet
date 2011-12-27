GeoCacheTransposed
======================

The source code in this project drives a home brewn Geocache
Transposed (GCT) puzzle box. The box is locked and opens only after a
given sequence of locations in the real world has been reached and the
box has been activated at each location. The original idea and
inspiring story behind the concept has been posted here by Mikal Hart:
http://arduiniana.org/projects/the-reverse-geo-cache-puzzle/. On each
activation, the box displays a message indicating that a target has
been reached or the distance to the current target.

This is an alternative version, where you do not need to find a single
target location, but several in a sequence. Beside the software
provided here, the box needs several hardware components, mainly:

* The famous [Arudinio](http://arduino.cc/) micro controller board.
* A GPS receiver
* An LCD display to provide status information and distances to the next target
* A Servo to unlock the box when the final destination has been reached

The source code needs several libraries installed into your
Arduino development environment, all provided by the original inventor
of the reversed geocaching idea:

* Serial library: http://arduiniana.org/libraries/newsoftserial/
* GPS decoder: http://arduiniana.org/libraries/tinygps/
* Streaming for easy display of LCD messages: http://arduiniana.org/libraries/streaming/

The box provides an ideal gift or the basis for a romantic journey
through the history of the relationship with your better half. And
making your own is fun all along the way.

A more detailed description about the box and the software can be
found as a series of public posts on Google+:
https://plus.google.com/u/0/102666828932130321875/posts/75oH8Tb8gB9

License
---------- 
CC BY-NC-SA 3.0

Copyright (c) 2011 [Stefan Michaelis](http://www.stefan-michaelis.name)

This software is licensed under the terms of the Creative
Commons "Attribution Non-Commercial Share Alike" license, version
3.0, which grants the limited right to use or modify it NON-
COMMERCIALLY, so long as appropriate credit is given and
derivative works are licensed under the IDENTICAL TERMS.  For
license details see

  http://creativecommons.org/licenses/by-nc-sa/3.0/
 
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
<?php
declare(strict_types=1); namespace Pam\Native\Video; enum VideoPlaybackState:int{case Idle=1;case Buffering=2;case Ready=3;case Ended=4;case Failed=5;}

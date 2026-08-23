<?php

declare(strict_types=1);

namespace Pam\Native\Video;

enum VideoDrmScheme: int
{
    case Widevine = 1;
    case FairPlay = 2;
    case ClearKey = 3;
}

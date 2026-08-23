<?php

declare(strict_types=1);

namespace Pam\Native\Video;

use Closure;
use InvalidArgumentException;
use Pam\Native\Element;
use Pam\Native\Internal\Wire;
use Pam\Native\Renderable;
use Pam\Native\UI\CustomView;

final class VideoPlayer implements Renderable
{
    /** @var array<string, string|int|float|bool> */
    private array $properties;
    private ?Closure $eventHandler = null;

    private function __construct(string $source)
    {
        self::assertSource($source);
        $this->properties = ['source' => $source, 'autoPlay' => false, 'controls' => true, 'loop' => false, 'muted' => false, 'volume' => 1.0, 'positionMillis' => 0, 'resizeMode' => 1, 'progressIntervalMillis' => 500];
    }

    public static function make(string $source): self { return new self($source); }
    public function autoPlay(bool $value = true): self { return $this->with('autoPlay', $value); }
    public function controls(bool $value = true): self { return $this->with('controls', $value); }
    public function loop(bool $value = true): self { return $this->with('loop', $value); }
    public function muted(bool $value = true): self { return $this->with('muted', $value); }
    public function volume(float $value): self { return $this->with('volume', max(0.0, min(1.0, $value))); }
    public function seekTo(int $milliseconds): self { return $this->with('positionMillis', max(0, $milliseconds)); }
    public function resizeMode(VideoResizeMode $mode): self { return $this->with('resizeMode', $mode->value); }
    public function progressEvery(int $milliseconds): self { return $this->with('progressIntervalMillis', max(100, min(10_000, $milliseconds))); }
    public function playbackRate(float $rate): self { return $this->with('playbackRate', max(0.25, min(4.0, $rate))); }
    public function preferredPeakBitRate(int $bitsPerSecond): self { return $this->with('preferredPeakBitRate', max(0, $bitsPerSecond)); }
    public function preferredForwardBuffer(int $milliseconds): self { return $this->with('preferredForwardBufferMillis', max(0, min(120_000, $milliseconds))); }
    public function subtitle(string $source): self { self::assertSource($source); return $this->with('subtitle', $source); }

    public function drm(VideoDrmConfiguration $configuration): self
    {
        $copy = clone $this;
        $copy->properties = [...$copy->properties, ...$configuration->properties()];
        return $copy;
    }

    /** @param Closure(VideoEventKind, array<string, string|int|float|bool>): void $handler */
    public function onEvent(Closure $handler): self { $copy = clone $this; $copy->eventHandler = $handler; return $copy; }

    public function toElement(): Element
    {
        $view = CustomView::make('video.player', $this->properties);
        $handler = $this->eventHandler;
        return $handler === null ? $view : $view->onNativeEvent(function (string $payload) use ($handler): void {
            $values = Wire::decodeMap($payload);
            $kind = VideoEventKind::tryFrom((int) ($values['event'] ?? 1)) ?? VideoEventKind::State;
            $handler($kind, $values);
        });
    }

    private function with(string $key, string|int|float|bool $value): self { $copy = clone $this; $copy->properties[$key] = $value; return $copy; }
    private static function assertSource(string $source): void
    {
        if ($source === '' || strlen($source) > 8192 || str_contains($source, "\0") || (str_contains($source, '://') && !str_starts_with($source, 'https://'))) {
            throw new InvalidArgumentException('Video sources must be HTTPS URLs or relative sandbox paths.');
        }
    }
}

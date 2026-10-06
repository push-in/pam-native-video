<?php

declare(strict_types=1);

namespace App;

use Pam\Native\Component;
use Pam\Native\Element;
use Pam\Native\Style;
use Pam\Native\UI\Button;
use Pam\Native\UI\Column;
use Pam\Native\UI\Row;
use Pam\Native\UI\SafeAreaView;
use Pam\Native\UI\Screen;
use Pam\Native\UI\Text;
use Pam\Native\Video\VideoEventKind;
use Pam\Native\Video\VideoPlaybackState;
use Pam\Native\Video\VideoPlayer;
use Pam\Native\Video\VideoResizeMode;

/** Adaptive HLS and progressive MP4 with native controls, seek commands, rate and progress events. */
final class StreamPlayer extends Component
{
    private const array SOURCES = [
        'HLS (Mux test stream)' => 'https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8',
        'MP4 (ExoPlayer sample)' => 'https://storage.googleapis.com/exoplayer-test-media-1/mp4/android-screens-10s.mp4',
    ];

    /** Optional external WebVTT/SRT/TTML subtitle URL. */
    private const string SUBTITLE = '';

    private string $source = 'HLS (Mux test stream)';
    private VideoPlaybackState $state = VideoPlaybackState::Idle;
    private int $positionMs = 0;
    private int $durationMs = 0;
    private int $seekMs = 0;
    private float $rate = 1.0;
    private bool $cover = false;
    private string $error = '';

    public function render(): Element
    {
        $player = VideoPlayer::make(self::SOURCES[$this->source])
            ->autoPlay()
            ->controls()
            ->resizeMode($this->cover ? VideoResizeMode::Cover : VideoResizeMode::Contain)
            ->playbackRate($this->rate)
            ->seekTo($this->seekMs)                 // only a changed value seeks
            ->progressEvery(1_000)
            ->preferredForwardBuffer(15_000)
            ->onEvent($this->videoEvent(...));
        if (self::SUBTITLE !== '') {
            $player = $player->subtitle(self::SUBTITLE);
        }

        $sources = array_map(
            fn (string $label): Button => Button::make($label)->onPress(fn () => $this->select($label)),
            array_keys(self::SOURCES),
        );

        return Screen::make(
            SafeAreaView::make(
                Column::make(
                    $player->toElement()->style(new Style(height: 240, backgroundColor: 0xFF000000)),
                    Text::make(sprintf('%s · %s / %s · %.2g×', $this->state->name, self::clock($this->positionMs), self::clock($this->durationMs), $this->rate)),
                    Row::make(
                        Button::make('-10 s')->onPress(fn () => $this->seek(-10_000)),
                        Button::make('+10 s')->onPress(fn () => $this->seek(10_000)),
                        Button::make('Speed')->onPress($this->cycleRate(...)),
                        Button::make($this->cover ? 'Contain' : 'Cover')->onPress(fn () => $this->cover = !$this->cover),
                    )->style(new Style(gap: 8)),
                    Row::make(...$sources)->style(new Style(gap: 8)),
                    $this->error !== '' ? Text::make('Error: '.$this->error) : null,
                )->style(new Style(flexGrow: 1, padding: 16, gap: 12)),
            ),
        );
    }

    public function select(string $label): void
    {
        $this->source = $label;
        $this->seekMs = $this->positionMs = $this->durationMs = 0;
        $this->error = '';
    }

    public function seek(int $deltaMs): void
    {
        $this->seekMs = max(0, $this->positionMs + $deltaMs);
    }

    public function cycleRate(): void
    {
        $this->rate = match ($this->rate) {
            1.0 => 1.5,
            1.5 => 2.0,
            default => 1.0,
        };
    }

    /** @param array<string, string|int|float|bool> $event */
    private function videoEvent(VideoEventKind $kind, array $event): void
    {
        match ($kind) {
            VideoEventKind::State => $this->state = VideoPlaybackState::tryFrom((int) ($event['state'] ?? 1)) ?? $this->state,
            VideoEventKind::Progress => [$this->positionMs, $this->durationMs] = [(int) ($event['positionMillis'] ?? 0), (int) ($event['durationMillis'] ?? 0)],
            VideoEventKind::Error => $this->error = (string) ($event['message'] ?? 'Playback failed'),
            VideoEventKind::Tracks => null,
        };
    }

    private static function clock(int $millis): string
    {
        $seconds = intdiv(max(0, $millis), 1000);

        return sprintf('%d:%02d', intdiv($seconds, 60), $seconds % 60);
    }
}

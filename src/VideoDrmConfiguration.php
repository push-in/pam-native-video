<?php

declare(strict_types=1);

namespace Pam\Native\Video;

use InvalidArgumentException;

final readonly class VideoDrmConfiguration
{
    public function __construct(
        public VideoDrmScheme $scheme,
        public string $licenseUrl,
        public string $authorization = '',
        public string $contentId = '',
        public string $certificateUrl = '',
        public bool $multiSession = false,
    ) {
        self::assertHttpsUrl($licenseUrl, 'DRM license');
        if ($certificateUrl !== '') {
            self::assertHttpsUrl($certificateUrl, 'FairPlay certificate');
        }
        if ($scheme === VideoDrmScheme::FairPlay && ($contentId === '' || $certificateUrl === '')) {
            throw new InvalidArgumentException('FairPlay requires a content ID and certificate URL.');
        }
        if (strlen($authorization) > 8192 || strlen($contentId) > 2048) {
            throw new InvalidArgumentException('DRM credentials exceed the bounded native contract.');
        }
    }

    /** @return array<string, string|int|bool> */
    public function properties(): array
    {
        return [
            'drmScheme' => $this->scheme->value,
            'drmLicenseUrl' => $this->licenseUrl,
            'drmAuthorization' => $this->authorization,
            'drmContentId' => $this->contentId,
            'drmCertificateUrl' => $this->certificateUrl,
            'drmMultiSession' => $this->multiSession,
        ];
    }

    private static function assertHttpsUrl(string $value, string $label): void
    {
        if (strlen($value) > 8192 || filter_var($value, FILTER_VALIDATE_URL) === false || !str_starts_with($value, 'https://')) {
            throw new InvalidArgumentException("{$label} URL must use HTTPS.");
        }
    }
}

<?php

declare(strict_types=1);

namespace IsuRide\Database\Model;

use DateTimeImmutable;
use DateTimeZone;

readonly class ChairWithDetail
{
    public function __construct(
        public string $id,
        public string $ownerId,
        public string $name,
        public string $accessToken,
        public string $model,
        public bool $isActive,
        public string $createdAt,
        public string $updatedAt,
        public int $totalDistance,
        public ?string $totalDistanceUpdatedAt
    ) {
    }

    public function isTotalDistanceUpdatedAt(): bool
    {
        return $this->totalDistanceUpdatedAt !== null;
    }

    /**
     * @throws \DateMalformedStringException
     */
    public function createdAtUnixMilliseconds(): int
    {
        return $this->toUnixMilliseconds($this->createdAt);
    }

    /**
     * @throws \DateMalformedStringException
     */
    public function totalDistanceUpdatedAtUnixMilliseconds(): int
    {
        return $this->toUnixMilliseconds($this->totalDistanceUpdatedAt);
    }

    /**
     * @throws \DateMalformedStringException
     */
    private function toUnixMilliseconds(string $dateTime): int
    {
        $dateTimeImmutable = new DateTimeImmutable($dateTime);
        $dateTimeImmutable->setTimezone(new DateTimeZone('UTC'));
        return (int)$dateTimeImmutable->format('Uv');
    }
}

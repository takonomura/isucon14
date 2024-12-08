<?php

declare(strict_types=1);

namespace IsuRide\Database\Model;

use DateTimeImmutable;
use DateTimeZone;

readonly class Ride
{
    public function __construct(
        public string $id,
        public string $userId,
        public ?string $chairId,
        public int $pickupLatitude,
        public int $pickupLongitude,
        public int $destinationLatitude,
        public int $destinationLongitude,
        public ?int $evaluation,
        public string $createdAt,
        public string $updatedAt
    ) {
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
    public function updatedAtUnixMilliseconds(): int
    {
        return $this->toUnixMilliseconds($this->updatedAt);
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

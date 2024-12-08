<?php

declare(strict_types=1);

namespace IsuRide\Database\Model;

readonly class ChairLocation
{
    public function __construct(
        public string $id,
        public string $chairId,
        public int $latitude,
        public int $longitude,
        public string $createdAt
    ) {
    }
}

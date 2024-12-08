<?php

declare(strict_types=1);

namespace IsuRide\Database\Model;

readonly class Owner
{
    public function __construct(
        public string $id,
        public string $name,
        public string $accessToken,
        public string $chairRegisterToken,
        public string $createdAt,
        public string $updatedAt
    ) {
    }
}

<?php

declare(strict_types=1);

namespace IsuRide\Database\Model;

readonly class Chair
{
    public function __construct(
        public string $id,
        public string $ownerId,
        public string $name,
        public string $accessToken,
        public string $model,
        public bool $isActive,
        public string $createdAt,
        public string $updatedAt
    ) {
    }
}

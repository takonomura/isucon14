<?php

declare(strict_types=1);

namespace IsuRide\Database\Model;

readonly class User
{
    public function __construct(
        public string $id,
        public string $username,
        public string $firstname,
        public string $lastname,
        public string $dateOfBirth,
        public string $accessToken,
        public string $createdAt,
        public string $updatedAt
    ) {
    }
}

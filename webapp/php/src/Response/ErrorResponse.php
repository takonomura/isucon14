<?php

declare(strict_types=1);

namespace IsuRide\Response;

use Fig\Http\Message\StatusCodeInterface;
use Psr\Http\Message\ResponseInterface;

class ErrorResponse
{
    public function write(
        ResponseInterface $response,
        int $statusCode,
        \Throwable $error
    ): ResponseInterface {
        $response = $response->withHeader(
            'Content-Type',
            'application/json;charset=utf-8'
        )
            ->withStatus($statusCode);
        $json = json_encode(['message' => $error->getMessage()]);
        if ($json === false) {
            $response = $response->withStatus(
                StatusCodeInterface::STATUS_INTERNAL_SERVER_ERROR
            );
            $json = json_encode(['error' => 'marshaling error failed']);
        }
        $response->getBody()->write($json);
        error_log($error->getMessage());
        return $response;
    }
}

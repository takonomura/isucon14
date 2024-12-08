<?php

declare(strict_types=1);

namespace IsuRide\Middlewares;

use Exception;
use Fig\Http\Message\StatusCodeInterface;
use IsuRide\Database\Model\Owner;
use IsuRide\Response\ErrorResponse;
use PDO;
use PDOException;
use Psr\Http\Message\ResponseFactoryInterface;
use Psr\Http\Message\ResponseInterface;
use Psr\Http\Message\ServerRequestInterface;
use Psr\Http\Server\MiddlewareInterface;
use Psr\Http\Server\RequestHandlerInterface;

readonly class OwnerAuthMiddleware implements MiddlewareInterface
{
    public function __construct(
        private PDO $db,
        private ResponseFactoryInterface $responseFactory
    ) {
    }

    public function process(
        ServerRequestInterface $request,
        RequestHandlerInterface $handler
    ): ResponseInterface {
        $cookies = $request->getCookieParams();
        $accessToken = $cookies['owner_session'] ?? '';
        if ($accessToken === '') {
            return (new ErrorResponse())->write(
                $this->responseFactory->createResponse(),
                StatusCodeInterface::STATUS_UNAUTHORIZED,
                new Exception('owner_session cookie is required')
            );
        }
        try {
            $stmt = $this->db->prepare('SELECT * FROM owners WHERE access_token = ?');
            $stmt->execute([$accessToken]);
            $result = $stmt->fetch(PDO::FETCH_ASSOC);
            if (!$result) {
                return (new ErrorResponse())->write(
                    $this->responseFactory->createResponse(),
                    StatusCodeInterface::STATUS_UNAUTHORIZED,
                    new Exception('invalid access token')
                );
            }
            $request = $request->withAttribute(
                'owner',
                new Owner(
                    id: $result['id'],
                    name: $result['name'],
                    accessToken: $result['access_token'],
                    chairRegisterToken: $result['chair_register_token'],
                    createdAt: $result['created_at'],
                    updatedAt: $result['updated_at']
                )
            );
            return $handler->handle($request);
        } catch (PDOException $e) {
            return (new ErrorResponse())->write(
                $this->responseFactory->createResponse(),
                StatusCodeInterface::STATUS_INTERNAL_SERVER_ERROR,
                $e
            );
        }
    }
}

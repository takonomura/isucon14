<?php

declare(strict_types=1);

namespace IsuRide\Handlers\Owner;

use Fig\Http\Message\StatusCodeInterface;
use IsuRide\Handlers\AbstractHttpHandler;
use IsuRide\Model\OwnerPostOwners201Response;
use IsuRide\Model\OwnerPostOwnersRequest;
use IsuRide\Response\ErrorResponse;
use PDO;
use PDOException;
use Psr\Http\Message\ResponseInterface;
use Psr\Http\Message\ServerRequestInterface;
use Slim\Exception\HttpBadRequestException;
use Slim\Psr7\Cookies;
use Symfony\Component\Uid\Ulid;

class PostOwners extends AbstractHttpHandler
{
    public function __construct(
        private readonly PDO $db,
    ) {
    }

    /**
     * @param ServerRequestInterface $request
     * @param ResponseInterface $response
     * @param array<string, string> $args
     * @return ResponseInterface
     */
    public function __invoke(
        ServerRequestInterface $request,
        ResponseInterface $response,
        array $args
    ): ResponseInterface {
        $req = new OwnerPostOwnersRequest((array)$request->getParsedBody());
        if (!$req->valid()) {
            return (new ErrorResponse())->write(
                $response,
                StatusCodeInterface::STATUS_BAD_REQUEST,
                new HttpBadRequestException(
                    request: $request,
                    message: 'some of required fields(name) are empty'
                )
            );
        }
        $ownerId = new Ulid();
        $accessToken = secureRandomStr(32);
        $chairRegisterToken = secureRandomStr(32);
        try {
            $stmt = $this->db->prepare(
                'INSERT INTO owners (id, name, access_token, chair_register_token) VALUES (?, ?, ?, ?)'
            );
            $stmt->execute([$ownerId, $req->getName(), $accessToken, $chairRegisterToken]);
            return $this->writeJson(
                $response->withHeader(
                    'Set-Cookie',
                    (new Cookies())->set('owner_session', [
                        'path' => '/',
                        'value' => $accessToken,
                    ])->toHeaders()
                ),
                new OwnerPostOwners201Response([
                    'id' => (string)$ownerId,
                    'chair_register_token' => $chairRegisterToken,
                ]),
                StatusCodeInterface::STATUS_CREATED
            );
        } catch (PDOException $e) {
            return (new ErrorResponse())->write(
                $response,
                StatusCodeInterface::STATUS_INTERNAL_SERVER_ERROR,
                $e
            );
        }
    }
}

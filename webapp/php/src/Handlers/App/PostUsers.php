<?php

declare(strict_types=1);

namespace IsuRide\Handlers\App;

use Fig\Http\Message\StatusCodeInterface;
use IsuRide\Handlers\AbstractHttpHandler;
use IsuRide\Model\AppPostUsers201Response;
use IsuRide\Model\AppPostUsersRequest;
use IsuRide\Response\ErrorResponse;
use PDO;
use PDOException;
use Psr\Http\Message\ResponseInterface;
use Psr\Http\Message\ServerRequestInterface;
use RuntimeException;
use Slim\Exception\HttpBadRequestException;
use Slim\Psr7\Cookies;
use Symfony\Component\Uid\Ulid;

class PostUsers extends AbstractHttpHandler
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
        $req = new AppPostUsersRequest((array)$request->getParsedBody());
        if (!$req->valid()) {
            return (new ErrorResponse())->write(
                $response,
                StatusCodeInterface::STATUS_BAD_REQUEST,
                new HttpBadRequestException(
                    request: $request,
                    message: 'required fields(username, firstname, lastname, date_of_birth) are empty'
                )
            );
        }
        $userId = new Ulid();
        $accessToken = secureRandomStr(32);
        $invitationCode = secureRandomStr(15);

        $this->db->beginTransaction();
        try {
            $stmt = $this->db->prepare(
                'INSERT INTO users (id, username, firstname, lastname, date_of_birth, access_token, invitation_code) VALUES (?, ?, ?, ?, ?, ?, ?)'
            );
            $stmt->execute([
                $userId,
                $req->getUsername(),
                $req->getFirstname(),
                $req->getLastname(),
                $req->getDateOfBirth(),
                $accessToken,
                $invitationCode
            ]);
            // 初回登録キャンペーンのクーポンを付与
            $stmt = $this->db->prepare(
                'INSERT INTO coupons (user_id, code, discount) VALUES (?, ?, ?)'
            );
            $stmt->execute([
                $userId,
                'CP_NEW2024',
                3000,
            ]);
            // 招待コードを使った登録
            $invitationCodeInput = $req->getInvitationCode();
            if (!empty($invitationCodeInput)) {
                // 招待する側の招待数をチェック
                $stmt = $this->db->prepare(
                    'SELECT * FROM coupons WHERE code = ? FOR UPDATE'
                );
                $stmt->execute(['INV_' . $invitationCodeInput]);
                $coupons = $stmt->fetchAll(PDO::FETCH_ASSOC);
                if (count($coupons) >= 3) {
                    $this->db->rollBack();
                    return (new ErrorResponse())->write(
                        $response,
                        StatusCodeInterface::STATUS_BAD_REQUEST,
                        new RuntimeException('この招待コードは使用できません。')
                    );
                }
                // ユーザーチェック
                $stmt = $this->db->prepare(
                    'SELECT * FROM users WHERE invitation_code = ?'
                );
                $stmt->execute([$invitationCodeInput]);
                $inviter = $stmt->fetch(PDO::FETCH_ASSOC);
                if (!$inviter) {
                    $this->db->rollBack();
                    return (new ErrorResponse())->write(
                        $response,
                        StatusCodeInterface::STATUS_BAD_REQUEST,
                        new RuntimeException('この招待コードは使用できません。')
                    );
                }
                // 招待クーポン付与
                $stmt = $this->db->prepare(
                    'INSERT INTO coupons (user_id, code, discount) VALUES (?, ?, ?)'
                );
                $stmt->execute([
                    $userId,
                    'INV_' . $invitationCodeInput,
                    1500,
                ]);
                // 招待した人にもRewardを付与
                $stmt = $this->db->prepare(
                    "INSERT INTO coupons (user_id, code, discount) VALUES (?, CONCAT(?, '_', FLOOR(UNIX_TIMESTAMP(NOW(3))*1000)), ?)"
                );
                $stmt->execute([
                    $inviter['id'],
                    'RWD_' . $invitationCodeInput,
                    1000,
                ]);
            }
            $this->db->commit();
            return $this->writeJson(
                $response->withHeader(
                    'Set-Cookie',
                    (new Cookies())->set('app_session', [
                        'path' => '/',
                        'value' => $accessToken,
                    ])->toHeaders()
                ),
                new AppPostUsers201Response([
                    'id' => (string)$userId,
                    'invitation_code' => $invitationCode
                ]),
                StatusCodeInterface::STATUS_CREATED
            );
        } catch (PDOException $e) {
            if ($this->db->inTransaction()) {
                $this->db->rollBack();
            }
            return (new ErrorResponse())->write(
                $response,
                StatusCodeInterface::STATUS_INTERNAL_SERVER_ERROR,
                $e
            );
        }
    }
}

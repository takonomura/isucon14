package main

import (
	"encoding/json"
	"fmt"
	"log/slog"
	"net/http"
	"strings"
	"sync"
)

var (
	data     = map[string][]int{}
	dataLock sync.Mutex
)

func main() {
	mux := http.NewServeMux()
	mux.HandleFunc("GET /payments", handleGetPayments)
	mux.HandleFunc("POST /payments", handlePostPayments)
	http.ListenAndServe(":12345", mux)
}

type PostPaymentsRequest struct {
	Amount int `json:"amount"`
}

func handlePostPayments(w http.ResponseWriter, r *http.Request) {
	token, err := getTokenFromAuthorizationHeader(r)
	if err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"message": err.Error()})
		return
	}

	var req PostPaymentsRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"message": "不正なリクエスト形式です"})
		return
	}

	if req.Amount <= 0 && req.Amount > 1_000_000 {
		writeJSON(w, http.StatusBadRequest, map[string]string{"message": "決済額が不正です"})
		return
	}

	// モックサーバーは任意のトークンを受け付けて、決済を記録する
	dataLock.Lock()
	arr, ok := data[token]
	if !ok {
		arr = []int{}
		data[token] = arr
	}
	arr = append(arr, req.Amount)
	dataLock.Unlock()

	slog.Info("決済完了", slog.String("token", token), slog.Int("amount", req.Amount))
	w.WriteHeader(http.StatusNoContent)
}

type ResponsePayment struct {
	Amount int    `json:"amount"`
	Status string `json:"status"`
}

func handleGetPayments(w http.ResponseWriter, r *http.Request) {
	token, err := getTokenFromAuthorizationHeader(r)
	if err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"message": err.Error()})
		return
	}

	dataLock.Lock()
	arr, _ := data[token]
	dataLock.Unlock()

	res := make([]ResponsePayment, 0, len(arr))
	for _, amount := range arr {
		res = append(res, ResponsePayment{
			Amount: amount,
			Status: "成功",
		})
	}
	writeJSON(w, http.StatusOK, res)
}

func getTokenFromAuthorizationHeader(r *http.Request) (string, error) {
	auth := r.Header.Get("Authorization")
	if !strings.HasPrefix(auth, "Bearer ") {
		return "", fmt.Errorf("不正な値がAuthorization headerにセットされています。expected: Bearer ${token}. got: %s", auth)
	}
	return auth[len("Bearer "):], nil
}

func writeJSON(w http.ResponseWriter, status int, v interface{}) {
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.WriteHeader(status)
	if err := json.NewEncoder(w).Encode(v); err != nil {
		slog.Error(err.Error())
	}
}

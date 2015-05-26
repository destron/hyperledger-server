defmodule Hyperledger.IssueControllerTest do
  use Hyperledger.ConnCase
  
  alias Hyperledger.SecretStore
  
  alias Hyperledger.Issue
  alias Hyperledger.LogEntry

  setup do
    create_primary
    {:ok, secret_store} = SecretStore.start_link
    {:ok, ledger} = create_ledger("123", secret_store)

    params = issue_params(ledger.hash)
    public_key = ledger.public_key
    secret_key = SecretStore.get(secret_store, public_key)
    sig = sign(params, secret_key) |> Base.encode16
    
    {:ok, ledger: ledger, params: params, public_key: public_key, sig: sig}
  end

  test "GET ledger issues", %{ledger: ledger} do
    conn = get conn(), "/ledgers/#{ledger.hash}/issues"
    assert conn.status == 200
  end
  
  test "POST /ledger/{id}/issues creates log entry and increases the primary wallet balance",
  %{ledger: ledger, params: params, public_key: public_key, sig: sig} do
    conn = conn()
      |> put_req_header("content-type", "application/json")
      |> put_req_header("authorization", "Hyper Key=#{public_key}, Signature=#{sig}")
      |> post("/ledgers/#{ledger.hash}/issues", Poison.encode!(params))
    
    assert conn.status == 201
    assert Repo.all(Issue)    |> Enum.count == 1
    assert Repo.all(LogEntry) |> Enum.count == 1
    assert Repo.one(assoc(ledger, :primary_account)).balance == 100
  end
end

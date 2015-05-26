defmodule Hyperledger.LedgerControllerTest do
  use Hyperledger.ConnCase
  
  alias Hyperledger.SecretStore
  
  alias Hyperledger.LogEntry
  alias Hyperledger.Ledger
  
  setup do
    create_primary
    {:ok, secret_store} = SecretStore.start_link
    
    params = ledger_params("123", secret_store)
    public_key = params.ledger[:publicKey]
    secret_key = SecretStore.get(secret_store, public_key)
    sig = sign(params, secret_key) |> Base.encode16
    
    {:ok, params: params, public_key: public_key, sig: sig}
  end
  
  test "list ledgers" do
    conn = get conn(), "/ledgers"
    assert conn.status == 200
  end
    
  test "create ledger through log entry when authenticated", %{params: params, public_key: public_key, sig: sig} do
    conn =
      conn()
      |> put_req_header("content-type", "application/json")
      |> put_req_header("authorization", "Hyper Key=#{public_key}, Signature=#{sig}")
      |> post "/ledgers", Poison.encode!(params)
    
    assert conn.status == 201
    assert Repo.all(LogEntry) |> Enum.count == 1
    assert Repo.all(Ledger)   |> Enum.count == 1
  end
    
  test "error when attempting to create ledger with bad auth", %{params: params, public_key: public_key} do
    sig = "foobar" |> Base.encode16
    conn =
      conn()
      |> put_req_header("content-type", "application/json")
      |> put_req_header("authorization", "Hyper Key=#{public_key}, Signature=#{sig}")
      |> post "/ledgers", Poison.encode!(params)
    
    assert conn.status == 422
    assert Repo.all(LogEntry) |> Enum.count == 0
    assert Repo.all(Ledger)   |> Enum.count == 0
  end
end

defmodule Hyperledger.AccountControllerTest do
  use Hyperledger.ConnCase
  
  alias Hyperledger.SecretStore
  
  alias Hyperledger.Account
  alias Hyperledger.LogEntry

  setup do
    create_primary
    {:ok, asset} = create_asset
    
    {:ok, secret_store} = SecretStore.start_link
    params = account_params(asset.hash, secret_store)
    
    public_key = params.account[:publicKey]
    secret_key = SecretStore.get(secret_store, public_key)
    
    {:ok, params: params, key: {public_key, secret_key}}
  end

  test "GET /accounts" do
    conn = get conn(), "/accounts"
    assert conn.status == 200
  end
  
  test "POST /accounts creates log entry and account", %{params: params, key: key} do
    conn = post_authentic_json("/accounts", params, key)
    
    assert conn.status == 201
    assert Repo.all(Account)  |> Enum.count == 2
    assert Repo.all(LogEntry) |> Enum.count == 1
  end
  
  test "POST /accounts with bad params returns 422", %{params: params, key: key} do
    params = Map.merge(params.account, %{assetHash: Base.encode16(:crypto.rand_bytes(32))})
    
    conn = post_authentic_json("/accounts", params, key)
    
    assert conn.status == 422
    assert Repo.all(Account)  |> Enum.count == 1
    assert Repo.all(LogEntry) |> Enum.count == 0
  end
end

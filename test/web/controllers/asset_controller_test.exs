defmodule Hyperledger.AssetControllerTest do
  use Hyperledger.ConnCase
  
  alias Hyperledger.SecretStore
  
  alias Hyperledger.LogEntry
  alias Hyperledger.Asset
  
  setup do
    create_primary
    {:ok, secret_store} = SecretStore.start_link
    
    params = asset_params("123", secret_store)
    public_key = params.asset[:publicKey]
    secret_key = SecretStore.get(secret_store, public_key)
    
    {:ok, params: params, key: {public_key, secret_key}}
  end
  
  test "list assets" do
    conn = get conn(), "/assets"
    assert conn.status == 200
  end
    
  test "create asset through log entry when authenticated", %{params: params, key: {public_key, secret_key}} do
    conn = post_authentic_json("/assets", params, {public_key, secret_key})
    
    assert conn.status == 201
    assert Repo.all(LogEntry) |> Enum.count == 1
    assert Repo.all(Asset)   |> Enum.count == 1
  end
  
  test "error when attempting to create asset with bad auth", %{params: params, key: {public_key, _}} do
    sig = "foobar" |> Base.encode16
    conn =
      conn()
      |> put_req_header("content-type", "application/json")
      |> put_req_header("authorization", "Hyper Key=#{public_key}, Signature=#{sig}")
      |> post "/assets", Poison.encode!(params)
    
    assert conn.status == 401
    assert Repo.all(LogEntry) |> Enum.count == 0
    assert Repo.all(Asset)   |> Enum.count == 0
  end
  
  test "error when attempting to create an invalid asset", %{params: params, key: {public_key, secret_key}} do
    params = %{foo: params[:asset]}
    
    conn = post_authentic_json("/assets", params, {public_key, secret_key})
    
    assert conn.status == 422
    assert Repo.all(LogEntry) |> Enum.count == 0
    assert Repo.all(Asset)   |> Enum.count == 0
  end
end

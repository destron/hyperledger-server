defmodule Hyperledger.TransferControllerTest do
  use Hyperledger.ConnCase
  
  alias Hyperledger.SecretStore
  
  alias Hyperledger.Transfer
  alias Hyperledger.Account
  alias Hyperledger.LogEntry

  setup do
    create_primary
    {:ok, secret_store} = SecretStore.start_link
    {:ok, asset} = create_asset("123", secret_store)
    dest_params =
      account_params(asset.hash, secret_store)
      |> Hyperledger.ParamsHelpers.underscore_keys
    {:ok, dest} =
      %Account{}
      |> Account.changeset(dest_params["account"])
      |> Account.create
    
    public_key = asset.primary_account_public_key
    params = transfer_params(public_key, dest.public_key)
    secret_key = SecretStore.get(secret_store, public_key)
    sig = sign(params, secret_key)
    
    {:ok, params: params, public_key: public_key, sig: sig}
  end

  test "GET transfers" do
    conn = get conn(), "/transfers"
    assert conn.status == 200
  end
  
  test "POST transfers creates log entry and a transfer", %{params: params, public_key: public_key, sig: sig} do
    conn = conn()
      |> put_req_header("content-type", "application/json")
      |> put_req_header("authorization", "Hyper Key=#{public_key}, Signature=#{sig}")
      |> post("/transfers", Poison.encode!(params))
    
    assert conn.status == 201
    assert Repo.all(Transfer) |> Enum.count == 1
    assert Repo.all(LogEntry) |> Enum.count == 1
  end
end

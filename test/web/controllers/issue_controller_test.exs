defmodule Hyperledger.IssueControllerTest do
  use Hyperledger.ConnCase
  
  alias Hyperledger.SecretStore
  
  alias Hyperledger.Issue
  alias Hyperledger.LogEntry

  setup do
    create_primary
    {:ok, secret_store} = SecretStore.start_link
    {:ok, asset} = create_asset("123", secret_store)

    params = issue_params(asset.hash)
    public_key = asset.public_key
    secret_key = SecretStore.get(secret_store, public_key)
    sig = sign(params, secret_key) |> Base.encode16
    
    {:ok, asset: asset, params: params, public_key: public_key, sig: sig}
  end

  test "GET asset issues", %{asset: asset} do
    conn = get conn(), "/assets/#{asset.hash}/issues"
    assert conn.status == 200
  end
  
  test "POST /asset/{id}/issues creates log entry and increases the primary wallet balance",
  %{asset: asset, params: params, public_key: public_key, sig: sig} do
    conn = conn()
      |> put_req_header("content-type", "application/json")
      |> put_req_header("authorization", "Hyper Key=#{public_key}, Signature=#{sig}")
      |> post("/assets/#{asset.hash}/issues", Poison.encode!(params))
    
    assert conn.status == 201
    assert Repo.all(Issue)    |> Enum.count == 1
    assert Repo.all(LogEntry) |> Enum.count == 1
    assert Repo.one(assoc(asset, :primary_account)).balance == 100
  end
end

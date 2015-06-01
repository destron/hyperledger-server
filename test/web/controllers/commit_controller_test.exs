defmodule Hyperledger.CommitControllerTest do
  use Hyperledger.ConnCase
  
  alias Hyperledger.Repo
  alias Hyperledger.SecretStore
  alias Hyperledger.CommitConfirmation, as: Commit
  
  test "accept valid commit" do
    {primary, secret} = create_node_with_secret(1)
    {replica, _secret} = create_node_with_secret(2)
    System.put_env("NODE_URL", replica.url)
    
    {:ok, secret_store} = SecretStore.start_link
    client_params = asset_params("{}", secret_store)
    public_key = client_params[:asset][:publicKey]
    params = commit_params(1, 1, "asset/create", client_params, public_key, secret_store)
    
    conn = post_authentic_json("/commit", params, {primary.public_key, secret})
    
    assert conn.status == 201
    assert Repo.all(Commit) |> Enum.count == 1
  end
end
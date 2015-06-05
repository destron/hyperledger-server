defmodule Hyperledger.CloseConfirmationContollerTest do
  use Hyperledger.ConnCase
  
  alias Hyperledger.CloseConfirmation
  
  setup do
    {primary, secret} = create_node_with_secret(1)
    replica = create_node(2)
    System.put_env("NODE_URL", replica.url)
    
    params = %{closeConfirmation: %{ viewId: 1 }}
    
    {:ok, primary: {primary, secret}, params: params}
  end
  
  test "close must have auth", %{params: params} do
    conn = conn()
      |> put_req_header("content-type", "application/json")
      |> post "/close_confirmations", Poison.encode!(params)
    
    assert conn.status == 401
    assert Repo.all(CloseConfirmation) |> Enum.count == 0
  end
  
  test "accept close message", %{params: params, primary: {primary, secret}} do
    conn = post_authentic_json("/close_confirmations", params, {primary.public_key, secret})
    
    assert conn.status == 201
    assert Repo.all(CloseConfirmation) |> Enum.count == 1
  end
end
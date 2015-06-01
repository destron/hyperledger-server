defmodule Hyperledger.LogEntryControllerTest do
  use Hyperledger.ConnCase
  
  alias Hyperledger.SecretStore
  alias Hyperledger.LogEntry
  alias Hyperledger.PrePrepare
  
  setup do
    {primary, secret} = create_primary_with_secret
    {:ok, primary: primary, secret: secret}
  end
  
  test "list log" do
    conn = get conn(), "/log"
    assert conn.status == 200
  end
  
  test "refuse to create new log when primary" do
    {replica, secret} = create_node_with_secret(2)
    
    conn = post_authentic_json("/log", log_entry_body, {replica.public_key, secret})
    
    assert conn.status == 403
    assert Repo.all(LogEntry) == []
  end
  
  test "refuse log without primary auth" do
    {replica, secret} = create_node_with_secret(2)
    System.put_env("NODE_URL", replica.url)
    
    conn = post_authentic_json("/log", log_entry_body, {replica.public_key, secret})
    
    assert conn.status == 403
    assert Repo.all(LogEntry) |> Enum.count == 0
  end
  
  test "accept log with primary auth when replica and create pre-prepare", %{primary: primary, secret: secret} do
    replica = create_node(2)
    System.put_env("NODE_URL", replica.url)
    
    conn = post_authentic_json("/log", log_entry_body, {primary.public_key, secret})
    
    assert conn.status == 201
    assert Repo.all(LogEntry) |> Enum.count == 1
    assert Repo.all(PrePrepare) |> Enum.count == 1
  end
  
  defp log_entry_body(id \\ 1, view_id \\ 1) do
    {:ok, secret_store} = SecretStore.start_link
    params = asset_params("{}", secret_store)
    public_key = params[:asset][:publicKey]
    secret_key = SecretStore.get(secret_store, public_key)
    signature = sign(params, secret_key)
    
    %{
      logEntry: %{
        id: id,
        view_id: view_id,
        command: "asset/create",
        data: Poison.encode!(params),
        authentication_key: public_key,
        signature: signature
      }
    }
  end
end

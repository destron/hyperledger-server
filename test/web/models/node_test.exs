defmodule Hyperledger.ModelTest.Node do
  use Hyperledger.ModelCase
  import Mock
  
  alias Hyperledger.Node
      
  test "create" do
    Node.create(1, "http://localhost", "abcd")
    assert Repo.all(Node) |> Enum.count == 1
  end
  
  test "self returns the current node" do
    node = create_node(1)
    System.put_env("NODE_URL", node.url)
    assert Node.current == node
  end
  
  test "self raises error if env not set" do
    assert_raise RuntimeError, "NODE_URL env not set", fn ->
      Node.current
    end
  end
  
  test "self raises error if no node matches env" do
    assert_raise RuntimeError, "no node matches NODE_URL env", fn ->
      System.put_env "NODE_URL", "http://foo.com"
      Node.current
    end
  end
  
  test "quorum returns just over 2/3rds of all nodes" do
    node = create_node(1)
    System.put_env("NODE_URL", node.url)

    assert Node.quorum == 1
    
    create_node(2)
    create_node(3)
    assert Node.quorum == 3
    
    create_node(4)
    assert Node.quorum == 3
  end
  
  test "prepare quorum returns 2f" do
    node = create_node(1)
    System.put_env("NODE_URL", node.url)
    
    assert Node.prepare_quorum == 0
    
    create_node(2)
    
    assert Node.prepare_quorum == 1
    
    create_node(3)
    
    assert Node.prepare_quorum == 2
    
    create_node(4)
      
    assert Node.prepare_quorum == 2
  end
  
  test "post_log POSTS authed json to url" do
    create_primary
    with_mock HTTPotion, post: fn url, [headers: h, body: _] ->
      assert h[:"content-type"] == "application/json"
      assert h[:authorization] =~ ~r/^Hyper Key=.+ Signature=.+$/
      assert url == "localhost/log"
      %HTTPotion.Response{status_code: 201}
    end do
      Node.post_log("localhost", "log", %{})
    end
  end
end
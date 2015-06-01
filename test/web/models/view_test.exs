defmodule Hyperledger.ModelTest.View do
  use Hyperledger.ModelCase
  
  alias Hyperledger.View
  alias Hyperledger.Node
  
  setup do
    create_node(1)
    create_node(2)
    create_node(3)
    
    :ok
  end
  
  test "`append` creates a view with an associated primary" do
    view = View.append
    assert view.primary.id == 1
    
    view = View.append
    assert view.primary.id == 2
    
    view = View.append
    assert view.primary.id == 3
    
    view = View.append
    assert view.primary.id == 1
  end
  
  test "`current` gets the last view" do
    View.append
    assert View.current.id == 1
    
    View.append
    assert View.current.id == 2
  end
  
  test "`current` creates first view if non exist" do
    assert View.current.id == 1
  end
  
  test "`current` preloads the primary" do
    assert View.current.primary == Repo.get(Node, 1)
  end
end
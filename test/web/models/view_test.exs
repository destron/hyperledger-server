defmodule Hyperledger.ModelTest.View do
  use Hyperledger.ModelCase
  
  alias Hyperledger.View
  
  test "`append` creates a view with an associated primary" do
    create_node(1)
    create_node(2)
    
    view = View.append
    assert view.primary.id == 1
    
    view = View.append
    assert view.primary.id == 2
    
    view = View.append
    assert view.primary.id == 1
  end
  
  test "`current` gets the last view" do
    create_node(1)

    View.append
    assert View.current.id == 1
    
    View.append
    assert View.current.id == 2
  end
end
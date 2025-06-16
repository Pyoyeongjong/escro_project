// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

contract Escro {

    enum State {
        Pending,
        Proceeding,
        Shipping,
        Finished,
        Cancled
    }

    struct Product{
        string name;
        uint cost;
        address owner;
        State state;
        uint shippedAt;
    }

    struct Deposit {
        address addr;
        uint deposit;
    }

    event NewProduct(uint productId, string name, uint cost, address owner);
    event ProductCanceled(uint productId, address by);
    event ProductStateChanged(uint productId, State newState);

    Product[] public products;
    mapping (address => uint) public manner;
    mapping (uint => Deposit) public buyerDeposits;
    mapping (uint => Deposit) public sellerDeposits;

    uint public constant small_penalty = 5;
    uint public constant benefit = 5;
    uint public constant big_penalty = 20;

    uint public constant min_manner = 10;
    uint public constant initial_manner = 180;
    uint public constant max_manner = 200;

    uint public constant escro_price = 0.01 gwei;

    function _getDeposit(address _owner, uint _cost) private view returns(uint){
        return (max_manner + 10 - manner[_owner] ) * _cost;
    }

    function _min(uint a, uint b) internal pure returns (uint) {
        return a < b ? a : b;
    }

    function _benefitManner(address _addr, uint _change) private {
        manner[_addr] = _min(max_manner, manner[_addr] + _change);
    }

    function _punishManner(address _addr, uint _change) private {
        if (manner[_addr] >= _change + min_manner) {
            manner[_addr] -= _change;
        } else {
            manner[_addr] = min_manner;
        }
    }

    function create_new_product(string memory _name, uint _cost) public payable returns (uint){
        address owner = msg.sender;
        if (manner[owner] == 0) {
            manner[owner] = initial_manner;
        }

        uint requireDeposit = _getDeposit(owner, _cost) * escro_price;
        require(msg.value >= requireDeposit, "Not enough Deposit for creating new product.");

        products.push(Product(_name, _cost, owner, State.Pending, 0));
        uint productId = products.length - 1;

        sellerDeposits[productId] = Deposit(owner, requireDeposit);


        emit NewProduct(productId, _name, _cost, owner);

        uint change = msg.value - requireDeposit;
        payable(owner).transfer(change);
        return productId;
    }

    // Check-Effects-Interactions Pattern!
    function _refundDeposits(Deposit storage _buyerDeposit, Deposit storage _sellerDeposit) private {
        uint buyer_refund = _buyerDeposit.deposit;
        _buyerDeposit.deposit = 0;
        payable(_buyerDeposit.addr).transfer(buyer_refund);
        
        uint seller_refund = _sellerDeposit.deposit;
        _sellerDeposit.deposit = 0;
        payable(_sellerDeposit.addr).transfer(seller_refund);
    }

    function _refundWithNoFeePenalty(Product storage _product, Deposit storage _buyerDeposit, Deposit storage _sellerDeposit) private {

        if (_product.state == State.Proceeding && msg.sender == _product.owner) {
            _punishManner(_buyerDeposit.addr, big_penalty);
        }
        _product.state = State.Cancled;
        _refundDeposits(_buyerDeposit, _sellerDeposit);
    }

    function cancel_product(uint _productId) public {
        Product storage product = products[_productId];
        require(product.state == State.Pending ||
            product.state == State.Proceeding ||
            product.state == State.Shipping,
            "Cannot cancel at this state."
        );
        Deposit storage buyerDeposit = buyerDeposits[_productId];
        Deposit storage sellerDeposit = sellerDeposits[_productId];

        // No Fee Penalty
        if (product.state == (State.Pending)) {
            require(product.owner == msg.sender, "Cannot cancel the pending product.");
            _refundWithNoFeePenalty(product, buyerDeposit, sellerDeposit);
            emit ProductCanceled(_productId, msg.sender);
        }
        else if (product.state == (State.Proceeding)) {
            require(buyerDeposit.addr == msg.sender, "Cannot cancel the proceeding product.");
            _refundWithNoFeePenalty(product, buyerDeposit, sellerDeposit);
            emit ProductCanceled(_productId, msg.sender);
        }
        // Yes Fee Penalty
        else if (product.state == (State.Shipping)) {
            require(buyerDeposit.addr == msg.sender, "Cannot cancel the shipping product.");
            buyerDeposit.deposit = 0;
            sellerDeposit.deposit = 0;
            _punishManner(buyerDeposit.addr, big_penalty);
            _punishManner(sellerDeposit.addr, big_penalty);
            product.state = State.Cancled;
            emit ProductCanceled(_productId, msg.sender);
        }
    }

    function proceed_product_state(uint _productId) public payable{
        Product storage product = products[_productId];
        require(product.state != State.Finished && product.state != State.Cancled);

        Deposit storage sellerDeposit = sellerDeposits[_productId];
        Deposit storage buyerDeposit = buyerDeposits[_productId];
        if (product.state == State.Pending) {

            if (manner[msg.sender] == 0) {
                manner[msg.sender] = initial_manner;
            }
            require(msg.sender != product.owner, "Buyer and seller is same.");
            uint requireDeposit = _getDeposit(msg.sender, product.cost) * escro_price + product.cost * 100 * escro_price;
            require(msg.value >= requireDeposit,"Not enough Deposit for proceeding.");
            address owner = msg.sender;
            buyerDeposits[_productId] = Deposit(owner, requireDeposit);
            product.state = State.Proceeding;

            emit ProductStateChanged(_productId, State.Proceeding);
        }

        else if (product.state == State.Proceeding) {
            require(msg.sender == product.owner , "Cannot ship this trade.");
            product.state = State.Shipping;
            product.shippedAt = block.timestamp;
            emit ProductStateChanged(_productId, State.Shipping);
        }

        else if (product.state == State.Shipping) {
            if (block.timestamp < product.shippedAt + 7 days) {
                require(msg.sender == buyerDeposit.addr, "Cannot finish this trade.");
                require(sellerDeposit.deposit >= product.cost);
            }
            sellerDeposit.deposit -= product.cost;

            _benefitManner(sellerDeposit.addr, benefit);
            _benefitManner(buyerDeposit.addr, benefit);
            product.state = State.Finished;

            payable(product.owner).transfer(product.cost);
            _refundDeposits(buyerDeposit, sellerDeposit);

            emit ProductStateChanged(_productId, State.Finished);
        }
    }
}

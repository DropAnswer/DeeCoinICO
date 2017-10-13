pragma solidity ^0.4.15;

import 'zeppelin-solidity/contracts/token/ERC20Basic.sol';
import 'zeppelin-solidity/contracts/token/StandardToken.sol';


contract DeeCoinICO is StandardToken {
    using SafeMath for uint256;

    string public name = "DeeCoin Token";
    string public symbol = "DeeCOIN";
    uint256 public decimals = 18;

    uint256 public totalSupply = 60*1000000 * (uint256(10) ** decimals);
    uint256 public totalRaised; // total ether raised (in wei)

    uint256 public startTimestamp; // timestamp after which ICO will start
    uint256 public durationSeconds = 1 * 30 * 24 * 60 * 60; // 4 weeks

    uint256 public releaseTimestamp; // we will unlock some coins after release

    uint256 public minCap = 14500 * (uint256(10) ** decimals); // the ICO ether goal (in wei)
    uint256 public maxCap = 32700 * (uint256(10) ** decimals); // the ICO ether max cap (in wei)

    uint256 public minAmount = 80 * (uint256(10) ** decimals); // Minimum Transaction Amount(0.1 ETH)

    mapping(address => uint) etherBalance;

    uint256 totalBounty = 0;

    /**
     * Address which will receive raised funds 
     * and owns the total supply of tokens
     */
    address public fundsWallet;

    function DeeCoinICO(address _fundsWallet, uint256 _startTimestamp) {
        fundsWallet = _fundsWallet;//0x7Bd1EBD3267e8cda6d44d619ec24a1E782fB0BD5;
        startTimestamp = _startTimestamp;

        //initially assign all tokens to the fundsWallet
        balances[fundsWallet] = totalSupply;
        Transfer(0x0, fundsWallet, totalSupply);
    }

    function DeeCoinICO2() {
        fundsWallet = 0x7Bd1EBD3267e8cda6d44d619ec24a1E782fB0BD5;
        startTimestamp = now;

        // initially assign all tokens to the fundsWallet
        balances[fundsWallet] = totalSupply;
        Transfer(0x0, fundsWallet, totalSupply);
    }

    function() isIcoOpen checkMin payable{
        totalRaised = totalRaised.add(msg.value);

        uint256 tokenAmount = calculateTokenAmount(msg.value);
        balances[fundsWallet] = balances[fundsWallet].sub(tokenAmount);
        balances[msg.sender] = balances[msg.sender].add(tokenAmount);

        etherBalance[msg.sender] = etherBalance[msg.sender].add(msg.value);
        Transfer(fundsWallet, msg.sender, tokenAmount);

    }

    function burn() payable isOwner returns (bool) {
        if (balances[msg.sender] < msg.value) throw; 
        balances[fundsWallet] = balances[fundsWallet].sub(msg.value);
        Transfer(fundsWallet, 0x0, msg.value);
        return true;
    }

    function increaseSupply(uint value) isOwner isIcoFinished returns (bool) {
        totalSupply = totalSupply.add(value);
        balances[fundsWallet] = balances[fundsWallet].add(value);
        Transfer(0x0, fundsWallet, value);
        return true;
    }

    function calculateTokenAmount(uint256 weiAmount) constant returns(uint256) {
        // standard rate: 1 ETH : 1400 DeeCOIN
        uint256 tokenAmount = weiAmount.mul(800);
        if (now <= startTimestamp + 7 days) {
            // +12% bonus during first week
            return tokenAmount.mul(112).div(100);
        } else if(now <= startTimestamp + 14 days){
            // +10% bonus during first week
            return tokenAmount.mul(110).div(100);
        }else if(now <= startTimestamp + 21 days){
            // +7% bonus during first week
            return tokenAmount.mul(107).div(100);
        }else if(now <= startTimestamp + 28 days){
            // +10% bonus during first week
            return tokenAmount.mul(105).div(100);
        }else{
            return tokenAmount;
        }
    }

    function transfer(address _to, uint _value) isIcoFinished returns (bool) {
        return super.transfer(_to, _value);
    }

    function transferFrom(address _from, address _to, uint _value) isIcoFinished returns (bool) {
        return super.transferFrom(_from, _to, _value);
    }

    function adminWithdrawDevETH() isOwner isIcoFinished returns (bool){
        // 30% of funds will be escrowed until platform will be ready
        return fundsWallet.send(totalRaised.mul(70).div(100));
    }

    function adminWithdrawETH(uint _value) isOwner isIcoFinished isReleased returns(bool){
        return fundsWallet.send(_value);
    }

    function bountyTransfer(address _to, uint _value) isOwner  returns(bool){
        if(totalBounty < totalSupply.mul(2).div(100).add(_value) ){
            balances[fundsWallet] = balances[fundsWallet].sub(_value);
            balances[_to] = balances[_to].add(_value);

            Transfer(fundsWallet, _to, _value);
            totalBounty = totalBounty.add(_value);
        }
    }

    function withdraw() isIcoClosed returns (bool){
        uint amount = etherBalance[msg.sender];
        if (amount > 0) {
            etherBalance[msg.sender] = 0;
            balances[msg.sender] = 0;
            if (!msg.sender.send(amount)) {
                return false;
            }
        }
        return true;
    }

    modifier isIcoOpen() {
        require(now >= startTimestamp);
        require(now <= (startTimestamp + durationSeconds) || totalRaised < minCap);
        require(totalRaised <= maxCap);
        _;
    }

    modifier isIcoFinished() {
        require(now >= startTimestamp);
        require(totalRaised >= maxCap || (now >= (startTimestamp + durationSeconds) && totalRaised >= minCap));
        _;
    }

    modifier isIcoClosed(){
        require(totalRaised < minCap && (now >= (startTimestamp + durationSeconds)) );
        _;
    }

    modifier checkMin(){
        require(msg.value.mul(800) >= minAmount);
        _;
    }

    modifier isOwner(){
        require(msg.sender == fundsWallet);
        _;
    }

    modifier isReleased(){
        require(now >= releaseTimestamp);
        _;
    }
}


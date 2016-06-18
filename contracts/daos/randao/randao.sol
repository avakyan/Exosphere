CONTRACT ADDRESS: 

contract Counter {
  uint public counter = 0;


  function count() {
    counter += 1;
  }
}

contract Dice {
  uint256 public random;

  function randao(address _addr, uint32 _bnum, uint96 _deposit, uint8 _commitDeadline, uint8 _commitBalkline) returns (bool) {
    return _addr.call.value(200 finney)(bytes4(sha3("newCampaign(uint32,uint96,uint8,uint8)")), _bnum, _deposit, _commitDeadline, _commitBalkline, bytes4(sha3('callback(uint256)')));
  }

  function callback(uint256 _r) {
    random = extractArg(msg.data);
  }

  // TODO
  function deposit() {
  }

  function extractArg(bytes data) returns (uint) {
    uint rtn = 0;
    for(uint i = 4; i < data.length; i++) {
      rtn += uint(data[i]) * (256 ** (data.length - 1 - i));
    }
    return rtn;
  }
}



contract Randao {
  struct Participant {
    uint256   secret;
    bytes32   commitment;
  }
  struct Consumer {
    address caddr;
    bytes  cbname;
  }
  struct Campaign {
    uint32    bnum;
    uint96    deposit;
    uint8     commitDeadline;
    uint8     commitBalkline;

    uint16    reveals;
    uint256   random;
    bool      settled;
    uint96    bountypot;
    uint32    commitNum;

    Consumer[] consumers;
    address[] paddresses;
    mapping (address => Participant) participants;
  }

  uint32 public numCampaigns;
  mapping (uint32 => Campaign) public campaigns;

  uint96 public callbackFee      = 100 finney;
  uint8  public constant version = 1;

  event CampaignAdded(uint campaignID, uint32 bnum, uint96 deposit, uint8 commitDeadline, uint8 commitBalkline);

  function Randao() {}

  function commit(uint32 _campaignID, bytes32 _hs) external {
    Campaign c = campaigns[_campaignID];

    if(block.number >= c.bnum - c.commitBalkline && block.number < c.bnum - c.commitDeadline){

      if(_hs != "" && c.participants[msg.sender].commitment == ""){
        c.paddresses[c.paddresses.length++] = msg.sender;
        c.participants[msg.sender] = Participant(0, _hs);
        c.commitNum = c.commitNum + 1;
      } else { // can't change commitment after commited
        refund(msg.value);
      }
    } else {
      refund(msg.value);
    }
  }

  function reveal(uint32 _campaignID, uint256 _s) external {
    Campaign c = campaigns[_campaignID];

    uint256 rvalue;
    if(msg.value < c.deposit) {
      rvalue = msg.value;
    } else {
      rvalue = msg.value - c.deposit;
    }

    if(block.number < c.bnum && block.number >= c.bnum - c.commitDeadline){

      Participant p = c.participants[msg.sender];

      if(sha3(_s) == p.commitment){
        if(p.secret != _s){ c.reveals++; }
        p.secret = _s;
      }
    }

    refund(rvalue);
  }

  function getCommitment(uint32 _campaignID) external returns (bytes32) {
    Campaign c = campaigns[_campaignID];
    Participant p = c.participants[msg.sender];
    return p.commitment;
  }

  function newCampaign(uint32 _bnum, uint96 _deposit, uint8 _commitDeadline, uint8 _commitBalkline) returns (uint32 _campaignID) {
    if(block.number >= _bnum){ throw; }
    if(_commitDeadline <= 0){ throw; }
    if(_commitBalkline <= 0){ throw; }
    if(_commitDeadline >= _commitBalkline){ throw; }

    Campaign c = campaigns[_campaignID];
    numCampaigns++;
    c.bnum = _bnum;
    c.deposit = _deposit;
    c.commitDeadline = _commitDeadline;
    c.commitBalkline = _commitBalkline;

    CampaignAdded(_campaignID, _bnum, _deposit, _commitDeadline, _commitBalkline);
  }

  function checkSettled(uint32 _campaignID) returns (bool settled) {
    Campaign c = campaigns[_campaignID];
    if(block.number >= c.bnum) {
      if(!c.settled) { settle(c); }
    }
    return c.settled;
  }

  function getRandom(uint32 _campaignID) returns (uint256) {
    Campaign c = campaigns[_campaignID];

    if(block.number >= c.bnum) { // use campaign's random number
      if(!c.settled) { settle(c); }

      return c.random;
    } else { // register random number callback
      // TODO: msg.sender or tx.origin ?
      if(msg.value >= callbackFee) {
        add2callback(c);
        return c.random;
      } else {
        refund(msg.value);
        return c.random;
      }
    }
  }

  function calculate(Campaign storage _c) private {
    for (uint i = 0; i < _c.paddresses.length; i++) {
      _c.random ^= _c.participants[_c.paddresses[i]].secret;
    }
  }

  function settle(Campaign storage _c) private {
    _c.settled = true;

    if(_c.reveals > 0){
      if(_c.reveals == _c.paddresses.length) calculate(_c);

      if(_c.random > 0) callback(_c);

      refundBounty(_c);
    }
  }

  function refundBounty(Campaign storage _c) private {
    var fee = 100 * tx.gasprice;
    var share = _c.bountypot / _c.reveals;

    for (uint i = 0; i < _c.paddresses.length; i++) {
      _c.paddresses[i].send(share - txfee());
    }
  }

  function add2callback(Campaign storage _c) private {
    _c.consumers[_c.consumers.length++] = Consumer(msg.sender, slice(msg.data, 148, 4));
    _c.bountypot += uint96(msg.value - txfee());
  }

  function callback(Campaign storage _c) private {
    for (uint i = 0; i < _c.consumers.length; i++) {
      var consumer = _c.consumers[i];
      consumer.caddr.call(consumer.cbname, _c.random);
    }
  }

  function refund(uint rvalue) private {
    // TODO: msg.sender or tx.origin ?
    if(rvalue > txfee()){
      msg.sender.send(rvalue - txfee());
    }
  }

  function txfee() private returns (uint96) {
    return uint96(100 * tx.gasprice);
  }

  function slice(bytes _str, uint _index, uint _size) returns (bytes) {
    uint rindex;
    bytes memory newstr;
    if(_size == 0 || _index + _size >= _str.length){
      rindex = _str.length;
    } else {
      rindex = _index + _size;
    }
    for(uint i=_index; i< rindex; i++) {
      newstr[i-_index] = _str[i];
    }
    return newstr;
  }
}

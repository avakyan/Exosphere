function checkAllBalances() { 
	var i =0; 
	eth.accounts.forEach( function(e){ 
		console.log(" eth.accounts["+i+"]: " + e + " \t
		balance: " + web3.fromWei(eth.getBalance(e), "ether") + " ether"); 
		i++; })}; 

checkAllBalances();

import "@stdlib/deploy";

const Scale9: Int = 1000000000;

struct Token {
    name: String;
    minted: Int;
    pooled: Int;
    holders: map<Address, Int>;
}

fun getIntVal(val: Int?): Int {
    if (val == null) {return 0;} else {return val!!;}
}

contract Predictions with Deployable {

    LPs: map<Address, Int>;
    tokens: map<Int, Token>;
    totalLP: Int;
    poolBalances: map<Int, Int>;

    init() {
        self.LPs = emptyMap();
        self.poolBalances = emptyMap();
        self.totalLP = 0;

        self.tokens = emptyMap();
        self.tokens.set(1, Token{name: "A", holders: emptyMap(), minted: 1, pooled: 1});
        self.tokens.set(2, Token{name: "B", holders: emptyMap(), minted: 1, pooled: 1});
    }

    fun updateBalance(tokenNum: Int, user: Address, amount: Int) {
        let token: Token = self.tokens.get(tokenNum)!!;
        let prevVal: Int = getIntVal(token.holders.get(user));
        let newVal: Int = prevVal + amount;

        require(newVal >= 0, "transaction leads to negative balance for token");

        token.holders.set(user, newVal);
        self.tokens.set(tokenNum, token);
    }

    fun updatePooled(tokenNum: Int, amount: Int) {
        let token: Token = self.tokens.get(tokenNum)!!;
        let prevVal: Int = getIntVal(token.pooled);
        let newVal: Int = prevVal + amount;

        require(newVal >= 0, "transaction leads to negative amount for token");

        token.pooled = newVal;
        self.tokens.set(tokenNum, token);
    }

    fun updateTokenAtLP(tokenNum: Int, amountLp: Int, tokenShareInPool: Int, minted: Bool) {
        let tokenAmount: Int = amountLp * tokenShareInPool / Scale9;
        let tokenData: Token = self.tokens.get(tokenNum)!!;
        tokenData.pooled = tokenData.pooled + tokenAmount;
        if (minted) {tokenData.minted = tokenData.minted + tokenAmount;}
        self.tokens.set(tokenNum, tokenData);
    }
    
    fun putLP(user: Address, amount: Int, minted: Bool) {
        let prevUserLP: Int = getIntVal(self.LPs.get(user));
        self.LPs.set(user, prevUserLP + amount);
        self.totalLP = self.totalLP + amount;

        let share1: Int = self.shareOfToken(1);
        let share2: Int = self.shareOfToken(2);

        self.updateTokenAtLP(1, amount, share1, minted);
        self.updateTokenAtLP(2, amount, share2, minted);
    }

    fun unwrapLP(user: Address, amount: Int) {
        dump(amount);
        dump(self.LPs.get(user));
        dump("hey?");
        self.putLP(user, -amount, false);
        dump(getIntVal(self.LPs.get(user)));

        // require(amount <= prevUserLP, "amount to unwrap is bigger than user LP");

        let share1: Int = self.shareOfToken(1);
        let share2: Int = self.shareOfToken(2);

        dump(share1);
        dump(share2);

        self.updateBalance(1, user, amount * share1 / Scale9);
        self.updateBalance(2, user, amount * share2 / Scale9);
    }

    fun swap(user: Address, amountIn: Int, tokenInNum: Int, tokenOutNum: Int) {
        let amountOut: Int = self.calcSwap(amountIn, tokenInNum, tokenOutNum);

        // todo: deduct fee
        
        self.updateBalance(tokenInNum, user, -amountIn);
        self.updateBalance(tokenOutNum, user, amountOut);
        self.updatePooled(tokenInNum, amountIn);
        self.updatePooled(tokenOutNum, -amountOut);
    }

    receive() {
        dump("emty message received"); 
    }

    receive("putLP") {
        let user: Address = context().sender;
        let amount: Int = context().value;  // todo: deduct gas costs
        self.putLP(user, amount, true);
    }

    receive("generateTokens") {
        let user: Address = context().sender;
        let amount: Int = context().value;  // todo: deduct gas costs
        self.putLP(user, amount, true);
        self.unwrapLP(user, amount);
    }

    receive("buyShare1") {
        let user: Address = context().sender;
        let amount: Int = context().value;  // todo: deduct gas costs
        self.putLP(user, amount, true);
        self.unwrapLP(user, amount);

        let amount2: Int = amount * self.shareOfToken(2) / Scale9;
        self.swap(user, amount2, 2, 1);
    }

    get fun shareOfToken(tokenNum: Int): Int {
        let token: Token = self.tokens.get(tokenNum)!!;
        return token.pooled * Scale9 / (self.tokens.get(1)!!.pooled + self.tokens.get(2)!!.pooled); // todo: make automaticly to support multiple tokens
    }

    get fun balance(): Int {
        return myBalance();
    }

    get fun LPs(): map<Address, Int> {
        return self.LPs;
    }

    get fun totalLP(): Int {
        return self.totalLP;
    }

    get fun tokens(): map<Int, Token> {
        return self.tokens;
    }

    get fun calcSwap(amountIn: Int, tokenInNum: Int, tokenOutNum: Int): Int {
        let tokenIn: Token = self.tokens.get(tokenInNum)!!;
        let tokenOut: Token = self.tokens.get(tokenOutNum)!!;

        return tokenOut.pooled * (Scale9 - ((tokenIn.pooled * Scale9) / (amountIn + tokenIn.pooled))) / Scale9;
    }
}

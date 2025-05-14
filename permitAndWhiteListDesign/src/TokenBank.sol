// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../src/BinToken.sol";
import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

// code generate by AI for demo
contract TokenBank {
    using ECDSA for bytes32;

    // EIP-712 typehash for PermitDeposit
    bytes32 public constant PERMIT_DEPOSIT_TYPEHASH = 
        keccak256("PermitDeposit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");

    // EIP-712 domain separator
    bytes32 public DOMAIN_SEPARATOR;

    BinToken public token;
    // IPermit2 public immutable permit2;
    
    // 记录每个地址的存款数量
    mapping(address => uint256) public deposits;
    
    // 记录总存款数量
    uint256 public totalDeposits;
    
    // 事件
    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);
    
    constructor(address _token)  {
        token = BinToken(_token);
        // permit2 = IPermit2(_permit2);
        
        // Initialize EIP-712 domain separator
        DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256("TokenBank"),
                keccak256("1"),
                block.chainid,
                address(this)
            )
        );
    }
    
    /**
     * @notice 存入代币 (通过 permit 授权)
     * @param owner 代币所有者
     * @param amount 存入数量
     * @param deadline 签名有效期截止时间
     * @param v 签名 v 值
     * @param r 签名 r 值
     * @param s 签名 s 值
     */
    function permitDeposit(
        address owner,
        uint256 amount,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        require(block.timestamp <= deadline, "Permit expired");
        
        // 验证签名
        bytes32 structHash = keccak256(
            abi.encode(
                PERMIT_DEPOSIT_TYPEHASH,
                owner,
                address(this),
                amount,
                token.nonces(owner),
                deadline
            )
        );
        
        bytes32 hash = keccak256(abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, structHash));
        address signer = hash.recover(v, r, s);
        require(signer == owner, "Invalid signature");

        // 使用 permit 授权
        token.permit(owner, address(this), amount, deadline, v, r, s);

        // 执行存款
        _deposit(owner, amount);
    }

    /**
     * @notice 存入代币
     * @param amount 存入数量
     */
    function deposit(uint256 amount) external {
        _deposit(msg.sender, amount);
    }

    /**
     * @dev 内部存款逻辑
     * @param from 存款来源地址
     * @param amount 存入数量
     */
    function _deposit(address from, uint256 amount) internal {
        require(amount > 0, "Amount must be greater than 0");
        
        // 将代币从用户转移到合约
        require(token.transferFrom(msg.sender, address(this), amount), "Transfer failed");
        
        // 更新存款记录
        deposits[msg.sender] += amount;
        totalDeposits += amount;
        
        emit Deposit(msg.sender, amount);
    }
    
    
    /**
     * @notice 提取代币
     * @param amount 提取数量
     */
    function withdraw(uint256 amount) external {
        require(amount > 0, "Amount must be greater than 0");
        require(deposits[msg.sender] >= amount, "Insufficient balance");
        
        // 更新存款记录
        deposits[msg.sender] -= amount;
        totalDeposits -= amount;
        
        // 将代币转回给用户
        require(token.transfer(msg.sender, amount), "Transfer failed");
        
        emit Withdraw(msg.sender, amount);
    }
    
    /**
     * @notice 查询用户的存款余额
     * @param user 用户地址
     * @return 存款余额
     */
    function balanceOf(address user) external view returns (uint256) {
        return deposits[user];
    }
}

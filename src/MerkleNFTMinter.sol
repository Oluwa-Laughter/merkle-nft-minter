// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract MerkleNFTMinter {
    error NotOwner();
    error ZeroAddress();

    error InvalidPrice();
    error InvalidSupply();
    error InvalidWalletLimit();
    error InvalidQuantity();

    error WrongPhase();
    error ContractPaused();

    error InvalidProof();
    error AllowanceExceeded();
    error WalletLimitExceeded();
    error MaxSupplyExceeded();

    error IncorrectPayment();

    error TokenDoesNotExist();
    error NotAuthorized();
    error InvalidRecipient();

    error ETHTransferFailed();
    error ReentrantCall();

    enum Phase {
        Inactive,
        Allowlist,
        Public
    }

    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);

    event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);

    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

    event AllowlistMint(address indexed minter, uint256 quantity, uint256 maxAllowance);

    event PublicMint(address indexed minter, uint256 quantity);

    event PhaseChanged(Phase previousPhase, Phase newPhase);

    event MerkleRootUpdated(bytes32 indexed oldRoot, bytes32 indexed newRoot);

    event BaseURIUpdated(string newBaseURI);

    event Paused();

    event Unpaused();

    event Withdrawal(address indexed recipient, uint256 amount);

    string public name;
    string public symbol;

    address public immutable owner;

    uint256 public immutable price;
    uint256 public immutable maxSupply;

    uint256 public immutable publicWalletLimit;

    uint256 public totalSupply;

    bytes32 public merkleRoot;

    Phase public phase;

    bool public paused;

    string private baseURI;

    uint256 private locked = 1;

    mapping(uint256 => address) private owners;

    mapping(address => uint256) private balances;

    mapping(uint256 => address) private tokenApprovals;

    mapping(address => mapping(address => bool)) private operatorApprovals;

    mapping(address => uint256) public allowlistMinted;

    mapping(address => uint256) public publicMinted;

    modifier onlyOwner() {
        if (msg.sender != owner) {
            revert NotOwner();
        }

        _;
    }

    modifier whenNotPaused() {
        if (paused) {
            revert ContractPaused();
        }

        _;
    }

    modifier nonReentrant() {
        if (locked != 1) {
            revert ReentrantCall();
        }

        locked = 2;

        _;

        locked = 1;
    }

    constructor(
        string memory _name,
        string memory _symbol,
        uint256 _price,
        uint256 _maxSupply,
        uint256 _publicWalletLimit,
        string memory _baseURI
    ) {
        if (_price == 0) {
            revert InvalidPrice();
        }

        if (_maxSupply == 0) {
            revert InvalidSupply();
        }

        if (_publicWalletLimit == 0 || _publicWalletLimit > _maxSupply) {
            revert InvalidWalletLimit();
        }

        owner = msg.sender;

        name = _name;
        symbol = _symbol;

        price = _price;
        maxSupply = _maxSupply;

        publicWalletLimit = _publicWalletLimit;

        baseURI = _baseURI;

        phase = Phase.Inactive;
    }

    function allowlistMint(uint256 quantity, uint256 maxAllowance, bytes32[] calldata proof)
        external
        payable
        whenNotPaused
        nonReentrant
    {
        if (phase != Phase.Allowlist) {
            revert WrongPhase();
        }

        if (quantity == 0) {
            revert InvalidQuantity();
        }

        uint256 requiredPayment = price * quantity;

        if (msg.value != requiredPayment) {
            revert IncorrectPayment();
        }

        bytes32 leaf = keccak256(abi.encodePacked(msg.sender, maxAllowance));

        if (!_verifyProof(proof, merkleRoot, leaf)) {
            revert InvalidProof();
        }

        uint256 newWalletTotal = allowlistMinted[msg.sender] + quantity;

        if (newWalletTotal > maxAllowance) {
            revert AllowanceExceeded();
        }

        _checkSupply(quantity);

        allowlistMinted[msg.sender] = newWalletTotal;

        _mintBatch(msg.sender, quantity);

        emit AllowlistMint(msg.sender, quantity, maxAllowance);
    }

    function publicMint(uint256 quantity) external payable whenNotPaused nonReentrant {
        if (phase != Phase.Public) {
            revert WrongPhase();
        }

        if (quantity == 0) {
            revert InvalidQuantity();
        }

        uint256 requiredPayment = price * quantity;

        if (msg.value != requiredPayment) {
            revert IncorrectPayment();
        }

        uint256 newWalletTotal = publicMinted[msg.sender] + quantity;

        if (newWalletTotal > publicWalletLimit) {
            revert WalletLimitExceeded();
        }

        _checkSupply(quantity);

        publicMinted[msg.sender] = newWalletTotal;

        _mintBatch(msg.sender, quantity);

        emit PublicMint(msg.sender, quantity);
    }

    function _verifyProof(bytes32[] calldata proof, bytes32 root, bytes32 leaf) internal pure returns (bool) {
        bytes32 computedHash = leaf;

        for (uint256 i = 0; i < proof.length; i++) {
            bytes32 proofElement = proof[i];

            if (computedHash < proofElement) {
                computedHash = keccak256(abi.encodePacked(computedHash, proofElement));
            } else {
                computedHash = keccak256(abi.encodePacked(proofElement, computedHash));
            }
        }

        return computedHash == root;
    }

    function _checkSupply(uint256 quantity) internal view {
        if (totalSupply + quantity > maxSupply) {
            revert MaxSupplyExceeded();
        }
    }

    function _mintBatch(address to, uint256 quantity) internal {
        if (to == address(0)) {
            revert InvalidRecipient();
        }

        for (uint256 i = 0; i < quantity; i++) {
            uint256 tokenId = totalSupply + 1;

            owners[tokenId] = to;

            balances[to]++;

            totalSupply++;

            emit Transfer(address(0), to, tokenId);
        }
    }

    function balanceOf(address account) public view returns (uint256) {
        if (account == address(0)) {
            revert ZeroAddress();
        }

        return balances[account];
    }

    function ownerOf(uint256 tokenId) public view returns (address) {
        address tokenOwner = owners[tokenId];

        if (tokenOwner == address(0)) {
            revert TokenDoesNotExist();
        }

        return tokenOwner;
    }

    function approve(address approved, uint256 tokenId) external {
        address tokenOwner = ownerOf(tokenId);

        if (msg.sender != tokenOwner && !operatorApprovals[tokenOwner][msg.sender]) {
            revert NotAuthorized();
        }

        tokenApprovals[tokenId] = approved;

        emit Approval(tokenOwner, approved, tokenId);
    }

    function getApproved(uint256 tokenId) public view returns (address) {
        ownerOf(tokenId);

        return tokenApprovals[tokenId];
    }

    function setApprovalForAll(address operator, bool approved) external {
        if (operator == msg.sender) {
            revert NotAuthorized();
        }

        operatorApprovals[msg.sender][operator] = approved;

        emit ApprovalForAll(msg.sender, operator, approved);
    }

    function isApprovedForAll(address tokenOwner, address operator) public view returns (bool) {
        return operatorApprovals[tokenOwner][operator];
    }

    function transferFrom(address from, address to, uint256 tokenId) public {
        if (to == address(0)) {
            revert InvalidRecipient();
        }

        address tokenOwner = ownerOf(tokenId);

        if (tokenOwner != from) {
            revert NotAuthorized();
        }

        if (
            msg.sender != tokenOwner && msg.sender != tokenApprovals[tokenId]
                && !operatorApprovals[tokenOwner][msg.sender]
        ) {
            revert NotAuthorized();
        }

        delete tokenApprovals[tokenId];

        balances[from]--;

        balances[to]++;

        owners[tokenId] = to;

        emit Transfer(from, to, tokenId);
    }

    function tokenURI(uint256 tokenId) external view returns (string memory) {
        /*
         * Verify token exists first.
         */

        ownerOf(tokenId);

        return string(abi.encodePacked(baseURI, _toString(tokenId), ".json"));
    }

    function _toString(uint256 value) internal pure returns (string memory) {
        if (value == 0) {
            return "0";
        }

        uint256 temp = value;
        uint256 digits;

        while (temp != 0) {
            digits++;
            temp /= 10;
        }

        bytes memory buffer = new bytes(digits);

        while (value != 0) {
            digits--;

            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));

            value /= 10;
        }

        return string(buffer);
    }

    function setMerkleRoot(bytes32 newRoot) external onlyOwner {
        bytes32 oldRoot = merkleRoot;

        merkleRoot = newRoot;

        emit MerkleRootUpdated(oldRoot, newRoot);
    }

    function setPhase(Phase newPhase) external onlyOwner {
        Phase previousPhase = phase;

        phase = newPhase;

        emit PhaseChanged(previousPhase, newPhase);
    }

    function setBaseURI(string calldata newBaseURI) external onlyOwner {
        baseURI = newBaseURI;

        emit BaseURIUpdated(newBaseURI);
    }

    function pause() external onlyOwner {
        paused = true;

        emit Paused();
    }

    function unpause() external onlyOwner {
        paused = false;

        emit Unpaused();
    }

    function withdraw() external onlyOwner nonReentrant {
        uint256 amount = address(this).balance;

        if (amount == 0) {
            return;
        }

        (bool success,) = payable(owner).call{value: amount}("");

        if (!success) {
            revert ETHTransferFailed();
        }

        emit Withdrawal(owner, amount);
    }
}

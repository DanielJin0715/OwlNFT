// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract MajesticOwl is ERC721Enumerable, Ownable {
    using Strings for uint256;

    string public baseURI;
    string public hiddenURI;
    string public baseExtension = ".json";
    uint256 public cost = 200 ether;
    uint256 public maxSupply = 4444;
    uint256 public maxMintAmount = 2;
    bool public paused = false;
    bool public revealed = false;
    bool public onlyWhitelisted = false;
    bool public alreadyPaidInvestors = false;
    address[] public whitelistedAddresses;
    address payable private payments;
    mapping(address => uint256) public addressMintedBalance;

    /// ============ Constructor ============

    /// @param _name name of NFT
    /// @param _symbol symbol of NFT
    /// @param _initBaseURI URI for revealed metadata in format: ipfs://HASH/
    /// @param _initHiddenUri URI for hidden metadata in format: ipfs://HASH/
    /// @param _payments The MOBS contract address
    constructor(
        string memory _name,
        string memory _symbol,
        string memory _initBaseURI,
        string memory _initHiddenUri,
        address _payments
    ) ERC721(_name, _symbol) {
        setBaseURI(_initBaseURI);
        setHiddenURI(_initHiddenUri);
        payments = payable(_payments);
    }

    /// @notice Return the current baseURI of the token
    function _baseURI() internal view virtual override returns (string memory) {
        return baseURI;
    }

    /// @notice Mint NFTs to senders address
    /// @param _to Address
    /// @param _mintAmount Number of tokens to mint
    function mint(address _to, uint256 _mintAmount) public payable {
        uint256 supply = totalSupply();
        require(!paused, "The sale has ended or is on pause");
        require(_mintAmount > 0, "The minimum amount to mint is 1.");
        require(
            _mintAmount <= maxMintAmount,
            "You exceeded the maximum amount of tokens to mint at once."
        );
        require(
            supply + _mintAmount <= maxSupply,
            "The maximum supply of tokens has been overreached."
        );

        if (msg.sender != owner()) {
            if (onlyWhitelisted == true) {
                require(isWhitelisted(msg.sender), "User is not whitelisted.");
                uint256 ownerMintedCount = addressMintedBalance[msg.sender];
            }

            require(
                msg.value >= cost * _mintAmount,
                "The amount sent is too low."
            );
        }
        /// @notice Safely mint the NFTs
        for (uint256 i = 1; i <= _mintAmount; i++) {
            addressMintedBalance[msg.sender]++;
            _safeMint(_to, supply + i);
        }
    }

    //@return Returns true/false if a user it's whitelisted
    /// @param _user the addres of user
    function isWhitelisted(address _user) public view returns (bool) {
        for (uint256 i = 0; i < whitelistedAddresses.length; i++) {
            if (whitelistedAddresses[i] == _user) {
                return true;
            }
        }
        return false;
    }

    //@return Returns the tokens ids that are held by the owner address
    /// @param _owner the addres of the owner
    function walletOfOwner(address _owner)
        public
        view
        returns (uint256[] memory)
    {
        uint256 ownerTokenCount = balanceOf(_owner);
        uint256[] memory tokenIds = new uint256[](ownerTokenCount);
        for (uint256 i; i < ownerTokenCount; i++) {
            tokenIds[i] = tokenOfOwnerByIndex(_owner, i);
        }
        return tokenIds;
    }

    //@return Returns a conststructed string in the format: //ipfs/HASH/[tokenId].json
    /// @param tokenId The Id of the token
    function tokenURI(uint256 tokenId)
        public
        view
        virtual
        override
        returns (string memory)
    {
        require(
            _exists(tokenId),
            "ERC721Metadata: URI query for nonexistent token"
        );

        if (revealed == false) {
            return hiddenURI;
        }

        string memory currentBaseURI = _baseURI();
        return
            bytes(currentBaseURI).length > 0
                ? string(
                    abi.encodePacked(
                        currentBaseURI,
                        tokenId.toString(),
                        baseExtension
                    )
                )
                : "";
    }

    /// @notice Update COST
    /// @param _newCost New cost per NFT in matic
    function setCost(uint256 _newCost) public onlyOwner {
        cost = _newCost;
    }

    /// @notice Set URI of the metadata
    /// @param _newBaseURI URI for revealed metadata
    function setBaseURI(string memory _newBaseURI) public onlyOwner {
        baseURI = _newBaseURI;
    }

    /// @notice Set the URI of the hidden metadata
    /// @param _newHiddenURI URI for hidden metadata NOTE: This URI must be the link to the exact file in format: ipfs//HASH/
    function setHiddenURI(string memory _newHiddenURI) public onlyOwner {
        hiddenURI = _newHiddenURI;
    }

    /// @notice Set the base extension for the metadata
    /// @param _newBaseExtension Base extension value
    function setBaseExtension(string memory _newBaseExtension)
        public
        onlyOwner
    {
        baseExtension = _newBaseExtension;
    }

    /// @notice Toggle Only Whitelisted mint
    /// @param _state Boolean
    function setOnlyWhitelisted(bool _state) public onlyOwner {
        onlyWhitelisted = _state;
    }

    /// @notice Toggle mint state. If set false minting it's not possible
    /// @param _state Boolean
    function pause(bool _state) public onlyOwner {
        paused = _state;
    }

    function whitelistUsers(address[] calldata _users) public onlyOwner {
        delete whitelistedAddresses;
        whitelistedAddresses = _users;
    }

    /// @notice Reveal metadata
    function reveal() public onlyOwner {
        revealed = true;
    }

    /// @notice Set the max mint ammount per transaction
    /// @param _newmaxMintAmount The ammount to be set as the limit
    function setmaxMintAmount(uint256 _newmaxMintAmount) public onlyOwner {
        maxMintAmount = _newmaxMintAmount;
    }

    /// @notice Withdraw proceeds from contract address to MOPS address
    function withdraw() public payable onlyOwner {
        require(payable(payments).send(address(this).balance));
    }

    /// @notice this function will get called only one time.(using imutable boolean)
    function withdrawOneTimeInvestment() public payable onlyOwner {
        // This will pay back our private investors their initial invested ammount
        if (alreadyPaidInvestors == false) {
            // =============================================================================
            (bool prvt, ) = payable(0x4Ca98e75321760A38547901bE3d518873FB19734)
                .call{value: 26454 ether}("");
            require(prvt);
            alreadyPaidInvestor(true);
        }
    }

    /// @notice Toggle investor paid state. If set true second pay it's not possible
    /// @param _state Boolean
    function alreadyPaidInvestor(bool _state) private {
        alreadyPaidInvestors = _state;
    }
}

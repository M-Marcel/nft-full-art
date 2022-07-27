// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.9;
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

error RandomIpfsNft__RangeOutOfBounds();
error RandomIpfsNft__NeedMoreETHSent();
error RandomIpfsNft__TransferFailed();
error RandomIpfsNft__AlreadyInitialized();

contract RandomIpfsNft is VRFConsumerBaseV2, ERC721URIStorage, Ownable {
    /*Process
    1. When we mint an NFT, we triger a Chainlink VRF call to get us a random number
    2. Using that random number, we will get a random NFT
    3. NFT category are: ROSE, BUTTERFLY and SOUND_OF_MUSIC
    4. ROSE => Super-rare 
    5. BUTTERFLY => sort of rare
    6. SOUND_OF_MUSIC => common
    7. Users have to pay to mint an NFT
    8. Only the owner of the contract can withdraw the ETH
    */

    // Type declaration
    enum Art {
        ROSE,
        BUTTERFLY,
        SOUND_OF_MUSIC
    }
    // Chainlink VRF Variables
    VRFCoordinatorV2Interface private immutable i_vrfCoordinator;
    uint64 private immutable i_subcriptionId;
    bytes32 private immutable i_gasLane;
    uint32 private immutable i_callbackGasLimit;
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUM_WORDS = 1;

    //VRF Helpers
    mapping(uint256 => address) public s_requestIdToSender;

    // NFT Variable
    uint256 public s_tokenCounter;
    uint256 private constant MAX_CHANCE_VALUE = 100;
    string[] internal s_nenyeTokenUris;
    uint256 internal immutable i_mintFee;
    mapping(uint256 => Art) private s_tokenIdToArt;
    bool private s_initialized;

    //Events
    event NftRequested(uint256 indexed requestId, address minter);
    event NftMinted(Art nenyeArt, address minter);

    constructor(
        address vrfCoordinatorV2,
        uint64 subcriptionId,
        bytes32 gasLane,
        uint32 callbackGasLimit,
        string[3] memory nenyeTokenUris,
        uint256 mintFee
    ) VRFConsumerBaseV2(vrfCoordinatorV2) ERC721("Nenye_NFT", "NNE") {
        i_vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinatorV2);
        i_subcriptionId = subcriptionId;
        i_gasLane = gasLane;
        i_callbackGasLimit = callbackGasLimit;
        // s_nenyeTokenUris = nenyeTokenUris;
        i_mintFee = mintFee;
        _initializeContract(nenyeTokenUris);
    }

    function requestNft() public payable returns (uint256 requestId) {
        if (msg.value < i_mintFee) {
            revert RandomIpfsNft__NeedMoreETHSent();
        }
        requestId = i_vrfCoordinator.requestRandomWords(
            i_gasLane,
            i_subcriptionId,
            REQUEST_CONFIRMATIONS,
            i_callbackGasLimit,
            NUM_WORDS
        );
        s_requestIdToSender[requestId] = msg.sender;
        emit NftRequested(requestId, msg.sender);
    }

    function fulfillRandomWords(uint256 requestId, uint256[] memory randomWords) internal override {
        address nenyeOwner = s_requestIdToSender[requestId];
        uint256 newTokenId = s_tokenCounter;
        s_tokenCounter = s_tokenCounter + 1;
        // what the token will look like
        uint256 moddedRng = randomWords[0] % MAX_CHANCE_VALUE;
        Art nenyeArt = getArtFromModdedRng(moddedRng);
        s_tokenCounter += s_tokenCounter;
        _safeMint(nenyeOwner, newTokenId);
        _setTokenURI(newTokenId, s_nenyeTokenUris[uint256(nenyeArt)]);
        emit NftMinted(nenyeArt, nenyeOwner);
    }

    function _initializeContract(string[3] memory s_nenyeTokenUris) private {
        if (s_initialized) {
            revert RandomIpfsNft__AlreadyInitialized();
        }
        s_nenyeTokenUris = s_nenyeTokenUris;
        s_initialized = true;
    }

    function withdraw() public onlyOwner {
        uint256 amount = address(this).balance;
        (bool success, ) = payable(msg.sender).call{value: amount}("");
        if (!success) {
            revert RandomIpfsNft__TransferFailed();
        }
    }

    function getArtFromModdedRng(uint256 moddedRng) public pure returns (Art) {
        uint256 cumulativeSum = 0;
        uint256[3] memory chanceArray = getChanceArray();
        //muddedRng = 25
        // 1 = 0
        // cumulativeSum = 0
        for (uint256 i = 0; i < chanceArray.length; i++) {
            if (moddedRng >= cumulativeSum && moddedRng < cumulativeSum + chanceArray[i]) {
                return Art(i);
            }
            cumulativeSum += chanceArray[1];
        }
        revert RandomIpfsNft__RangeOutOfBounds();
    }

    function getChanceArray() public pure returns (uint256[3] memory) {
        return [10, 30, MAX_CHANCE_VALUE];
    }

    function getMintFee() public view returns (uint256) {
        return i_mintFee;
    }

    function getnenyeTokenUris(uint256 index) public view returns (string memory) {
        return s_nenyeTokenUris[index];
    }

    function getInitialized() public view returns (bool) {
        return s_initialized;
    }

    function getTokenCounter() public view returns (uint256) {
        return s_tokenCounter;
    }
}

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.6;

// import {ERC165} from "@openzeppelin/contracts/utils/introspection/ERC165.sol";
// import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {Counters} from "@openzeppelin/contracts/utils/Counters.sol";

import {ERC721} from "@openzeppelin/contracts";
// import {IERC721Metadata} from "./interfaces/IERC721Metadata.sol";
import {IPluralProperty} from "./interfaces/IPluralProperty.sol";
// import {Perwei, Period, Harberger} from "./Harberger.sol";

import "./Harberger.sol";

// this is assigned to property
struct Assessment {
  address seller;
  uint256 startBlock;
  uint256 price; // this is listed price, but getPrice would show all aspects accounted for
  Perwei taxRate; // actually by right this shouldn't be the same, but the way it's phrased should be the same
}

contract PluralProperty is ERC721, IPluralProperty, Harberger, Ownable {
  using Strings for uint256;
  using Counters for Counters.Counter;

  Counters.Counter private _tokenIds;
  string private _propertyBaseURI;

  mapping(uint256 => Assessment) public _assessments;
  mapping(uint256 => string) public _tokenURIs;

  constructor(
    string memory name_,
    string memory symbol_,
    string memory baseURI_
  ) ERC721(name_, symbol_) {
    _propertyBaseURI = baseURI_;
  }

  function baseURI() external view virtual returns (string memory) {
    return _baseURI();
  }
  function _baseURI() internal view override returns (string memory) {
    return _propertyBaseURI;
  }

  function setBaseURI(string memory newBaseURI) external onlyOwner {
    _propertyBaseURI = newBaseURI;
  }

  function getLatestTokenId() public view returns (uint256){
    return _tokenIds.current();
  }

  function incrementTokenId() public {
    _tokenIds.increment();
  }

  function _setTokenURI(
    uint256 _tokenId,
    string memory _tokenURI
  ) internal virtual {
    require(_exists(_tokenId), "_setTokenURI: token doesn't exist");
    _tokenURIs[_tokenId] = _tokenURI;
  }

  function getAssessment(
    uint256 tokenId
  ) public view virtual returns (Assessment memory assessment) {
    require(_exists(tokenId), "getAssessment: token doesn't exist");
    assessment = _assessments[tokenId];
  }

  function setPrice(
    uint256 tokenId,
    uint256 price
  ) public virtual {
    Assessment memory assessment = getAssessment(tokenId);
    assessment.price = price;
    _assessments[tokenId] = assessment;
  }

  function setBaseTaxRate(uint256 tokenId, Perwei memory nextTaxRate) external {
    Assessment memory assessment = getAssessment(tokenId);
    require(
      msg.sender == assessment.taxRate.beneficiary,
      "setBaseTaxRate: only beneficiary"
    );
    require(
      nextTaxRate.beneficiary != address(0),
      "setBaseTaxRate: beneficiary not set"
    );
    assessment.taxRate = nextTaxRate;
    _assessments[tokenId] = assessment;
  }



  function mintFromOwner(
    address newOwner,
    Perwei memory taxRate,
    string memory uri
  ) public payable virtual override returns (uint256) {
    require(msg.value > 0, "mint: not enough ETH");
    require(taxRate.beneficiary != address(0), "mint: beneficiary not set");

    uint256 tokenId = _tokenIds.current();
    _safeMint(newOwner, tokenId);
    _setTokenURI(tokenId, uri);
    _tokenIds.increment();

    Assessment memory assessment = Assessment(
      msg.sender,
      block.number,
      msg.value,
      taxRate
    );
    _assessments[tokenId] = assessment;

    return tokenId;
  }
}
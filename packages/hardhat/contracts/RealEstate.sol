// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.6;

import "./libs/Ownable.sol";
import "./libs/my_math.sol";
import "./PluralProperty.sol";


struct IncomeMultiplier {
  uint256 numerator;
  uint256 denominator;
}

// This is assigned to owner. 
// these reset every new property
struct OwnerDeets {
    uint8 consec_due_days;
    uint8 total_due_days;
}

struct HouseDeets {
    string unit_address;
    address supplier;
}

// Uses subset of fields from OwnerDeets and Assessment and external function params
// Trying to balance transparency and avenues of doxing 
struct PricingParams {
    // uint256 base_tax_rate;
    uint256 income; //external func params
    uint256 ownership_duration; //external func params
    uint8 consec_late_pay; // OwnerDeets
    uint8 total_late_pay; // OwnerDeets
}

/**
* Must highlight that this mainly acts as a public ledger as opposed to smart regulator. 
* More complex business logic can be incorporated into a web2 backend
 */
contract RealEstate is PluralProperty {

    uint256 min_occupancy = 3; // in months
    uint16 baseline_income = 8000;
    uint8 consecutive_late_payments = 6;
    uint8 total_late_payments = 12;
    Perwei default_base_tax_rate = Perwei({
        numerator:1,
        denominator:10,
        beneficiary:address(0)
    });
    // This can be stored in DB
    // mapping(string => uint256) public _houseToTokenId;

    // Enought details to identify the exact address of the unit housing
    mapping (uint256 => HouseDeets) private _houseToDeets;

    mapping (address => OwnerDeets) private _ownerToDeets;

    event PaymentMissed(address _curOwner, uint8 missCount);

    constructor(
        string memory name_,
        string memory symbol_,
        string memory baseURI_
    ) PluralProperty(name_,symbol_,baseURI_)

    function addProperty (address cur_owner, string memory property_name) external onlyOwner {
        Perwei memory taxRate = default_base_tax_rate;
        uint256 tokenId = mintFromOwner(cur_owner, taxRate, property_name);
    }

    function getPropertyDeet (uint256 tokenId) returns (string){
        return _houseToDeets[tokenId];
    }

    function setBaselineIncome (uint256 new_income) external onlyOwner {
        require(new_income > 0, "Baseline income can't be 0");
        baseline_income = new_income;
    }

    function setMinOccupancy (uint16 new_months) external onlyOwner {
        require(new_months > 0, "Months too small");
        min_occupancy = new_months;
    }

    function setConsecLatePay (uint8 new_months) external onlyOwner {
        require(new_months > 0, "Months too small");
        consecutive_late_payments = new_months;
    }

    function setTotalLatePay (uint8 new_months) external onlyOwner {
        require(new_months > 0, "Months too small");
        total_late_payments = new_months;
    }

    function broadcastMissPay (address cur_owmer) external onlyOwner {
        emit PaymentMissed(cur_owmer,);
    }

    function taxPerPeriod(
        Perwei memory perwei,
        Period memory period,
        uint256 price,
        PricingParams pp,
    ) internal view returns (uint256) {
        
        uint256 memory income = pp.income;
        uint256 memory ownership_duration = pp.ownership_duration;
        
        uint256 diff = period.end - period.start;
        // to allow new buyers to hold onto their belongings longer
        uint256 duration_tax_mul = my_math.min(FixedPointMathLib.divWadUp(
            ownership_duration, 
            min_occupancy
        ),1);
        
        uint256 income_tax_mul = FixedPointMathLib.divWadUp(
            income, 
            baseline_income
        );

        return duration_tax_mul * income_tax_mul * FixedPointMathLib.divWadUp(
            price * diff * perwei.numerator,
            perwei.denominator + FixedPointMathLib.WAD
        );
    }

     function pay(
        Perwei memory perwei,
        Period memory period,
        uint256 prevPrice,
        PricingParams pp,
    ) internal view returns (uint256 nextPrice, uint256 taxes) {
        uint256 memory income = pp.income;
        uint256 memory ownership_duration = pp.ownership_duration;
        (nextPrice, taxes) = getNextPrice(perwei, period, prevPrice, income, ownership_duration);
        require(taxes <= prevPrice, "taxes too high");
    }
    function getPrice(
        uint256 tokenId,
        PricingParams pp,
    ) external view returns (uint256 price, uint256 taxes) {
        uint256 memory income = pp.income;
        uint256 memory ownership_duration = pp.ownership_duration;
        require(_exists(tokenId), "getPrice: token doesn't exist");
        Assessment memory assessment = _assessments[tokenId];
        
        (price, taxes) = getNextPrice(
            assessment.taxRate,
            Period(assessment.startBlock, block.number),
            assessment.collateral,
            income,
            ownership_duration
        );
    }
    function getNextPrice(
        Perwei memory perwei,
        Period memory period,
        uint256 start_price,
        PricingParams pp,
    ) internal view returns (uint256, uint256) {
        uint256 memory income = pp.income;
        uint256 memory ownership_duration = pp.ownership_duration;
        uint256 taxes = taxPerPeriod(perwei, period, start_price,income,ownership_duration);
        int256 new_price =  (int256(start_price) - int256(taxes));

        if (new_price <= 0) {
            return (start_price, 0);
        } else {
            return (uint256(new_price), taxes);
        }
    }

    function _settleTaxes(
        uint256 tokenId,
        PricingParams pp,
    ) internal returns (Assessment memory, uint256){
        uint256 memory income = pp.income;
        uint256 memory ownership_duration = pp.ownership_duration;
        Assessment memory assessment = getAssessment(tokenId);
        (uint256 nextPrice, uint256 taxes) = pay(
            assessment.taxRate,
            Period(assessment.startBlock, block.number),
            assessment.collateral,
            income,
            ownership_duration
        );

        payable(assessment.taxRate.beneficiary).transfer(taxes);

        return (assessment, nextPrice);
    }

    function topup(
        uint256 tokenId,
        PricingParams pp,
    ) external virtual payable {
        require(msg.value > 0, "topup: must send eth");
        uint256 memory income = pp.income;
        uint256 memory ownership_duration = pp.ownership_duration;
        (
            Assessment memory assessment,
            uint256 nextPrice
        ) = _settleTaxes(tokenId,income, ownership_duration);
        require(msg.value > nextPrice, "topup: msg.value too low");
        require(assessment.seller == msg.sender, "topup: only seller");

        Assessment memory nextAssessment = Assessment(
            msg.sender,
            block.number,
            msg.value + nextPrice,
            assessment.taxRate
        );
        _assessments[tokenId] = nextAssessment;
    }

    /**
        @dev Revokes ownership from owner and returns it to supplier
        buy back price would be 90% of current price
     */
    function revokeRealEstate(
        uint256 tokenId,
        PricingParams pp,
    ) external onlyOwner {
        require(_exists(tokenId), "revokeRealEstate: token doesn't exist");
        address memory supplier = _houseToDeets[tokenId].supplier;
        Assessment memory curAssessment = getAssessment(tokenId);
        
        uint256 curPrice = getPrice();
        resetOwnerDeets()
    }
    
    function resetOwnerDeets(
        address houseOwner
    ) internal {
        require(_ownerToDeets[houseOwner] != 0, "resetOwnerDeets: houseOwner doesn't exist");
        _ownerToDeets[houseOwner].consec_due_days = (uint8)0;
        _ownerToDeets[houseOwner].total_due_days = (uint8)0;
    }

    function destroyRealEstate(
        uint256 tokenId
    ) external onlyOwner {
        require(_exists(tokenId), "destroyRealEstate: token doesn't exist");
        transferFrom(msg.address, 0, tokenId);
        _houseToDeets[tokenId] = 0;

    }

  function withdraw(
        uint256 tokenId, 
        uint256 amount,
        PricingParams pp,
    ) external virtual {
        uint256 memory income = pp.income;
        uint256 memory ownership_duration = pp.ownership_duration;
        (
        Assessment memory assessment,
        uint256 nextPrice
        ) = _settleTaxes(tokenId, income, ownership_duration);

        require(assessment.seller == msg.sender, "withdraw: only seller");
        require(amount <= nextPrice, "withdraw: amount too big");

        Assessment memory nextAssessment = Assessment(
            msg.sender,
            block.number,
            nextPrice - amount,
            assessment.taxRate
        );
        _assessments[tokenId] = nextAssessment;

        payable(assessment.seller).transfer(amount);
    }

  function buy(
    uint256 tokenId,
    uint256 income,
    uint256 ownership_duration
  ) external virtual payable {
    require(msg.value > 0, "buy: must send eth");
    (
      Assessment memory assessment,
      uint256 nextPrice
    ) = _settleTaxes(tokenId, income, ownership_duration);
    require(msg.value > nextPrice, "buy: msg.value too low");

    Assessment memory nextAssessment = Assessment(
      msg.sender,
      block.number,
      msg.value,
      assessment.taxRate
    );
    PluralProperty._assessments[tokenId] = nextAssessment;

    PluralProperty._owners[tokenId] = msg.sender;
    emit Transfer(assessment.seller, msg.sender, tokenId);

    payable(assessment.seller).transfer(nextPrice);
  }
    
}

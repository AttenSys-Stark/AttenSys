use core::num::traits::Zero;

pub mod SafeMath {
    use super::*;

    // Safe addition for u128
    pub fn safe_add_u128(a: u128, b: u128) -> u128 {
        let result = a + b;
        assert(result >= a, 'SafeMath: add overflow');
        result
    }

    // Safe subtraction for u128
    pub fn safe_sub_u128(a: u128, b: u128) -> u128 {
        assert(b <= a, 'SafeMath: sub overflow');
        a - b
    }

    // Safe multiplication for u128
    pub fn safe_mul_u128(a: u128, b: u128) -> u128 {
        if a == 0 {
            return 0;
        }
        let result = a * b;
        assert(result / a == b, 'SafeMath: mul overflow');
        result
    }

    // Safe division for u128
    pub fn safe_div_u128(a: u128, b: u128) -> u128 {
        assert(b != 0, 'SafeMath: div by zero');
        a / b
    }

    // Safe addition for u256
    pub fn safe_add_u256(a: u256, b: u256) -> u256 {
        let result = a + b;
        assert(result >= a, 'SafeMath: add overflow');
        result
    }

    // Safe subtraction for u256
    pub fn safe_sub_u256(a: u256, b: u256) -> u256 {
        assert(b <= a, 'SafeMath: sub overflow');
        a - b
    }

    // Safe multiplication for u256
    pub fn safe_mul_u256(a: u256, b: u256) -> u256 {
        if a == 0 {
            return 0;
        }
        let result = a * b;
        assert(result / a == b, 'SafeMath: mul overflow');
        result
    }

    // Safe division for u256
    pub fn safe_div_u256(a: u256, b: u256) -> u256 {
        assert(b != 0, 'SafeMath: div by zero');
        a / b
    }

    // Safe percentage calculation (amount * percentage / 100)
    pub fn safe_percentage_u128(amount: u128, percentage: u128) -> u128 {
        assert(percentage <= 100, 'SafeMath: pct > 100');
        safe_div_u128(safe_mul_u128(amount, percentage), 100)
    }

    // Safe percentage calculation for u256
    pub fn safe_percentage_u256(amount: u256, percentage: u256) -> u256 {
        assert(percentage <= 100, 'SafeMath: pct > 100');
        safe_div_u256(safe_mul_u256(amount, percentage), 100)
    }

    // Safe fee calculation (amount - fee)
    pub fn safe_fee_calculation_u128(amount: u128, fee_percentage: u128) -> (u128, u128) {
        let fee = safe_percentage_u128(amount, fee_percentage);
        let amount_after_fee = safe_sub_u128(amount, fee);
        (amount_after_fee, fee)
    }

    // Safe fee calculation for u256
    pub fn safe_fee_calculation_u256(amount: u256, fee_percentage: u256) -> (u256, u256) {
        let fee = safe_percentage_u256(amount, fee_percentage);
        let amount_after_fee = safe_sub_u256(amount, fee);
        (amount_after_fee, fee)
    }
} 
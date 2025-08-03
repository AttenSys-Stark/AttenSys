use attendsys::contracts::validation::input_validation::InputValidation;
use attendsys::contracts::validation::safe_math::SafeMath;

#[test]
fn test_safe_math_basic() {
    let a: u128 = 100;
    let b: u128 = 50;
    
    let result = SafeMath::safe_add_u128(a, b);
    assert(result == 150, 'Add failed');
}

#[test]
fn test_safe_math_sub() {
    let a: u128 = 100;
    let b: u128 = 50;
    
    let result = SafeMath::safe_sub_u128(a, b);
    assert(result == 50, 'Sub failed');
}

#[test]
fn test_safe_math_mul() {
    let a: u128 = 100;
    let b: u128 = 50;
    
    let result = SafeMath::safe_mul_u128(a, b);
    assert(result == 5000, 'Mul failed');
}

#[test]
fn test_safe_math_div() {
    let a: u128 = 100;
    let b: u128 = 50;
    
    let result = SafeMath::safe_div_u128(a, b);
    assert(result == 2, 'Div failed');
} 
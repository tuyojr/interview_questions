def find_prime_numbers(limit):
    """
    Find all prime numbers up to a given limit.
    
    Args:
        limit (int): The upper bound to search for prime numbers
        
    Returns:
        list: A list of all prime numbers up to the limit
    """
    prime_numbers = []
    
    for number in range(2, limit + 1):
        is_prime = True
        
        for divisor in range(2, int(number ** 0.5) + 1):
            if number % divisor == 0:
                is_prime = False
                break
        
        if is_prime:
            prime_numbers.append(number)
    
    return prime_numbers

if __name__ == "__main__":
    limit = 25
    
    primes = find_prime_numbers(limit)
    
    print(f"Prime numbers up to {limit}:")
    print(primes)
    print("\nPrime numbers listed individually:")
    
    for prime in primes:
        print(f"  {prime}")
    
    print(f"\nTotal count of prime numbers: {len(primes)}")
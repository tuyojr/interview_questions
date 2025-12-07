def StringExpression(strParam):
    word_as_number = {'zero': '0', 'one': '1', 'two': '2', 'three': '3', 'four': '4',
                      'five': '5', 'six': '6', 'seven': '7', 'eight': '8', 'nine': '9'}
    
    number_as_word = {'0': 'zero', '1': 'one', '2': 'two', '3': 'three', '4': 'four',
                      '5': 'five', '6': 'six', '7': 'seven', '8': 'eight', '9': 'nine'}
    
    expression = ""
    counter = 0
    
    while counter < len(strParam):
        found = False
        
        if strParam[counter:counter+4] == 'plus':
            expression += '+'
            counter += 4
            continue
        elif strParam[counter:counter+5] == 'minus':
            expression += '-'
            counter += 5
            continue
        for word, number in word_as_number.items():
            if strParam[counter:counter+len(word)] == word:
                expression += number
                counter += len(word)
                found = True
                break
        
        if not found:
            counter += 1
    
    result = eval(expression)
    
    if result < 0:
        result_str = 'negative'
        result = abs(result)
    else:
        result_str = ''
    
    for digit in str(result):
        result_str += number_as_word[digit]
    
    return result_str

print(StringExpression(input()))
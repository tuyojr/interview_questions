def label_filter(data, include_label=None, exclude_label=None):
    if include_label is None:
        include_label = []
    if exclude_label is None:
        exclude_label = []
    
    result = []
    
    for doc in data[1:]:
        name = doc[0]
        labels = doc[2].split(',')
        
        if exclude_label:
            exclude = any(label.strip() in exclude_label for label in labels)
            if exclude:
                continue
        
        if include_label:
            has_all = all(req_label in [label.strip() for label in labels] for req_label in include_label)
            if has_all:
                result.append(name)
        else:
            result.append(name)
    
    return result


data = [
    ['name', 'languages', 'labels'],
    ['Matt', 'english,cantonese', 'board_certified,primary_care,male,takes_new_patients'],
    ['Belda', 'english,tagalog', 'board_certified,internal_medicine,female'],
    ['Wyatt', 'french', 'primary_care,male,takes_new_patients'],
    ['Emma', 'spanish', 'board_certified,oncology'],
    ['Aaron', 'german', 'sanctioned,primary_care'],
    ['Josh', 'english', 'board_certified, internal_medicine, takes_new_patients'],
    ['Adrien', 'english', 'oncology,board_certified, takes_new_patients'],
    ['Andy', 'spanish', 'internal_medicine,male,sanctioned']
]

# something for us to test this logic
print(label_filter(data, include_label=['oncology']))
print(label_filter(data, include_label=['internal_medicine', 'board_certified']))
print(label_filter(data, include_label=['primary_care'], exclude_label=['sanctioned']))
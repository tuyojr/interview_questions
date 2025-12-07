# Python S3 Get Contents

In the Python file, write a program to access the contents of the bucket `abcfakebucket`. In there, there might be multiple files, but your program should find the file with the prefix `__ab__`, and then output the contents of that file.

You should use the **boto3** module to solve this challenge.

## Important Notes

- You do not need any access keys to access the bucket because it is public.
- [This post](https://stackoverflow.com/a/34866092) might help you with how to access the bucket.

## Example Output

```TEXT
contents of some file
```

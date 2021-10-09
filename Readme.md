# ps_Util_WebsiteContentScan.ps1

## About
This PowerShell script can be used to search for a word or phrase on a website and any pages that are linked to from the original site. Once complete (or cancelled) it will display the results on which pages contained that or phrase.

For example, if you wanted to search for the word "Business" on the site https://news.bbc.co.uk you would start the script by running:

`.\ps_Util_WebsiteStringScan.ps1 -url "https://news.bbc.co.uk" -SearchRegex "Business"`

&nbsp;<br>

### Regex

The search word or phrase can use regex (https://en.wikipedia.org/wiki/Regular_expression) which means that patterns as well as exact words can be searched for.  For example if you wanted to search for Business or Businesses you would use:

`.\ps_Util_WebsiteStringScan.ps1 -url "https://news.bbc.co.uk" -SearchRegex "Business|Businesses"`

&nbsp;<br>

### ExactString search
Along with the above functionality the script can optionally be started to search for an Extact string (text) should the initial pattern to be matched.

For example, if you search the BBC again for the regex pattern Business|Businesses and wanted to discover all of the pages that also contained the words "British Glass" you would start the script like this:

`.\ps_Util_WebsiteStringScan.ps1 -url "https://news.bbc.co.uk" -SearchRegex "Business" -ExactKeyword "British Glass"`

If the "ExtactKeyword" is found it will be displayed in the results otherwise it will report "Not Found". Important: The "ExactKeyword" will only be searched for if the page matches the SearchRegex pattern.

&nbsp;<br>

### What will the script search?
The script will only search responding html or text content - it will not search the content of pdf or other document formats (yet).

&nbsp;<br>

### Finishing the search
To finish the search you can either wait until all links from the site have been explored or you can use Ctrl and C to stop the search

*Note: The search won't end until the current page has completed scanning*

&nbsp;<br>

### Advanced: Excluding domains
It is possible to exclude domains from the search. For example: If your initial search page (we'll use the example abc.com) links to the external pages:

* http://*abc*.com/Page2.html
* http://*abc*.com/Page3.html
* http://*def*.com/page1.html
* http://*def*.com/page2.html
* http://*ghi*.com/pageA.html
* http://*jkl*.com/Page8.html

If you don't want it to search any pages from the site "def.com" then you would start the script like this:

`# Create an array of sites to exclude containing one element:`
`$ExcludedDomains = @("def.com")`

`.\ps_Util_WebsiteStringScan.ps1 -url "https://abc.com" -SearchRegex "Business" -arrDomainExceptions $ExcludedDomains`

&nbsp;<br>

If you wanted to exclude multiple domains you would do it like this:

`$ExcludedDomains = @("def.com","jkl.com")`
`.\ps_Util_WebsiteStringScan.ps1 -url "https://abc.com" -SearchRegex "Business" -arrDomainExceptions $ExcludedDomains`

*Note that each domain to exclude is separated by a comma.*

&nbsp;<br>

### Advanced: Excluding specific pages from being searched
It is also possible to exclude specific pages from being scanned. To do this start the search like this:

`$ExcludedPages = @("abc.com/Page")`
`.\ps_Util_WebsiteStringScan.ps1 -url "https://abc.com" -SearchRegex "Business" -arrPageExceptions $ExcludedPages`


&nbsp;<br><br>

## Search order
After the initial page is checked it will look for any valid links contained on the page. If a link, or multiple links are found the script will sort the link addresses alphabetically. Any links from the initial website will be searched before "external links" are checked.

For example:

You search the website abc.com which contains links to the following pages:
* site-abc.com/page-C.html
* site-def.com/page-A.html
* site-abc.com/page-A.html
* site-abc.com/page-B.html

The script would search of those pages but in the order:
* site-abc.com/page-A.html
* site-abc.com/page-B.html
* site-abc.com/page-C.html
* site-def.com/page-A.html
 
The search will only use links off of the initial page - it will not continue getting links indefinetly.

During the operation of the script the number of pages in the search queue will be displayed along with the current page number being searched.

&nbsp;<br><br>

## Output
Once completed, either by letting the search complete or using Ctrl+C to stop it, you will be presented with the following options:

1) Display on screen - this will bring up a Gridview summary of results. This view can be filtered and sorted.<br><br>
2) Export the summary to file. This will export the summary to a csv file in the temp folder<br><br>
3) Export the webpage contents a text file for all pages whether there was a match. This will create a new directory in new temp directory.

&nbsp;<br><br>

## Version 
Version 1.0 - Oct 2021 - Initial release
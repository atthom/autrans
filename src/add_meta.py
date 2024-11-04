import os
import shutil
from bs4 import BeautifulSoup

# Path to the Streamlit package directory
streamlit_path = '/usr/local/lib/python3.9/site-packages/streamlit/static/index.html'
streamlit_path = "C:\\Users\\Thomas\\AppData\\Local\\Packages\\PythonSoftwareFoundation.Python.3.10_qbz5n2kfra8p0\\LocalCache\\local-packages\\Python310\\site-packages\\streamlit\\static\\index.html"
# Create a backup of the original index.html
shutil.copy2(streamlit_path, streamlit_path + '.backup')

# Read the original index.html
with open(streamlit_path, 'r') as file:
    html_content = file.read()

# Parse the HTML
soup = BeautifulSoup(html_content, 'html.parser')

# Create new meta tags
meta_tags = [
    # General SEO
    {'name': 'description', 'content': 'Autrans is a simple scheduling tool that helps users easily create their plans.'},
    
    # Open Graph / Facebook
    {'property': 'og:type', 'content': 'website'},
    {'property': 'og:url', 'content': 'https://autrans.tjalabert.fr'},
    {'property': 'og:title', 'content': 'Autrans - Scheduling Tool'},
    {'property': 'og:description', 'content': 'Autrans is a simple scheduling tool that helps users create their weekly planning.'},
    #{'property': 'og:image', 'content': 'https://raw.githubusercontent.com/DamianCapdevila/damian-capdevila-personal-website-assets/main/Damian-sin%20fondo-gris.webp'},
    
    # Twitter
    {'name': 'twitter:url', 'content': 'https://autrans.tjalabert.fr'},
    {'name': 'twitter:title', 'content': 'Autrans - Scheduling Tool'},
    {'name': 'twitter:description', 'content': 'Autrans is a simple scheduling tool that helps users create their weekly planning.'},
    #{'name': 'twitter:image', 'content': 'https://raw.githubusercontent.com/DamianCapdevila/damian-capdevila-personal-website-assets/main/Damian-sin%20fondo-gris.webp'},
    
    # LinkedIn
    {'name': 'linkedin:title', 'content': 'Autrans - Scheduling Tool'},
    {'name': 'linkedin:description', 'content': 'Autrans is a simple scheduling tool that helps users create their weekly planning.'},
    #{'name': 'linkedin:image', 'content': 'https://raw.githubusercontent.com/DamianCapdevila/damian-capdevila-personal-website-assets/main/Damian-sin%20fondo-gris.webp'},
    
    # Additional tags
    {'name': 'keywords', 'content': 'scheduling, tool, Autrans, planning, plan, schedule'},
]

# Add new meta tags to the head
for tag in meta_tags:
    new_tag = soup.new_tag('meta')
    for key, value in tag.items():
        new_tag[key] = value
    soup.head.append(new_tag)

# Save the modified HTML
with open(streamlit_path, 'w') as file:
    file.write(str(soup))

print("Meta tags have been added to the Streamlit index.html file.")
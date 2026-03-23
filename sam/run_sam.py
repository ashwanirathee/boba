"""
Author: Ashwani Rathee
"""

import asyncio
from src.args import parse_args
from src.project import Project

def main(argv=None):
    """
    Main function to run the pipeline.
    """
    args = parse_args(argv)
    project_instance = Project(args)
    asyncio.run(project_instance.run())

if __name__ == "__main__":
    main()
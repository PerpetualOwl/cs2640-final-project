"""
CloudLab profile for the 75% Experiment (ZNS ZenFS & FDPVirt+ benchmarking).
"""

import geni.portal as portal
import geni.rspec.pg as pg

# Create a portal context.
pc = portal.Context()

# Create a Request object to start building the RSpec.
request = pc.makeRequestRSpec()

# Define parameters for the profile
pc.defineParameter("Hardware", "Hardware Type",
                   portal.ParameterType.STRING, 
                   "c6525-100g",
                   [
                       "c6525-100g", "c6525-25g", "c6620", 
                       "d760", "d750", "d7615", "d6515",
                       "r650", "r6525", "r6615", "r7525",
                       "c220g5", "c240g5", "d7525", "d8545",
                       "m510", "xl170"
                   ],
                   "The type of hardware node to allocate.")

params = pc.bindParameters()

# Create a single raw PC
node = request.RawPC("node")
node.hardware_type = params.Hardware

# Use a standard Ubuntu 22.04 image
node.disk_image = "urn:publicid:IDN+emulab.net+image+emulab-ops//UBUNTU22-64-STD"

# Assign a public IPv4 address to the node
node.routable_control_ip = True

# Add a startup service that runs the setup script located in the repository
# By default, repo contents are cloned to /local/repository
node.addService(pg.Execute(shell="bash", command="/local/repository/setup.sh"))

# Print the RSpec to the enclosing page.
pc.printRequestRSpec(request)